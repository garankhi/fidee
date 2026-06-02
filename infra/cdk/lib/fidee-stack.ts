import * as cdk from 'aws-cdk-lib';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaEventSources from 'aws-cdk-lib/aws-lambda-event-sources';
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as route53 from 'aws-cdk-lib/aws-route53';
import * as route53Targets from 'aws-cdk-lib/aws-route53-targets';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as wafv2 from 'aws-cdk-lib/aws-wafv2';
import { Construct } from 'constructs';

export const MAIN_REGION = 'ap-southeast-1';
export const CLOUDFRONT_WAF_REGION = 'us-east-1';
export const SUPPORTED_STAGES = ['dev', 'prod'] as const;

export type FideeStage = (typeof SUPPORTED_STAGES)[number];

export function assertFideeStage(stage: string): FideeStage {
  if (SUPPORTED_STAGES.includes(stage as FideeStage)) {
    return stage as FideeStage;
  }

  throw new Error(`Unsupported stage "${stage}". Use one of: ${SUPPORTED_STAGES.join(', ')}`);
}

interface StageProps extends cdk.StackProps {
  stage: FideeStage;
}

export type FideeMediaWafStackProps = StageProps;

export interface FideeStackProps extends StageProps {
  mediaWebAclArn: string;
}

const isProd = (stage: FideeStage) => stage === 'prod';
const resourceName = (stage: FideeStage, resource: string) => `fidee-${stage}-${resource}`;

function applyStageTags(scope: Construct, stage: FideeStage) {
  cdk.Tags.of(scope).add('Project', 'fidee');
  cdk.Tags.of(scope).add('Environment', stage);
  cdk.Tags.of(scope).add('CostCenter', 'fidee');
  cdk.Tags.of(scope).add('AutoCleanup', isProd(stage) ? 'false' : 'true');

  if (!isProd(stage)) {
    cdk.Tags.of(scope).add('TtlDays', '30');
  }
}

function managedRule(
  name: string,
  priority: number,
  managedRuleName: string,
): wafv2.CfnWebACL.RuleProperty {
  return {
    name,
    priority,
    overrideAction: { none: {} },
    statement: {
      managedRuleGroupStatement: {
        vendorName: 'AWS',
        name: managedRuleName,
      },
    },
    visibilityConfig: {
      cloudWatchMetricsEnabled: true,
      metricName: name,
      sampledRequestsEnabled: true,
    },
  };
}

function rateLimitRule(stage: FideeStage): wafv2.CfnWebACL.RuleProperty {
  return {
    name: 'RateLimit',
    priority: 40,
    action: { block: {} },
    statement: {
      rateBasedStatement: {
        aggregateKeyType: 'IP',
        limit: isProd(stage) ? 2000 : 1000,
      },
    },
    visibilityConfig: {
      cloudWatchMetricsEnabled: true,
      metricName: 'RateLimit',
      sampledRequestsEnabled: true,
    },
  };
}

function webAclRules(stage: FideeStage): wafv2.CfnWebACL.RuleProperty[] {
  return [
    managedRule('AwsCommonRules', 10, 'AWSManagedRulesCommonRuleSet'),
    managedRule('AwsKnownBadInputs', 20, 'AWSManagedRulesKnownBadInputsRuleSet'),
    managedRule('AwsIpReputation', 30, 'AWSManagedRulesAmazonIpReputationList'),
    rateLimitRule(stage),
  ];
}

export class FideeMediaWafStack extends cdk.Stack {
  public readonly webAclArn: string;

  constructor(scope: Construct, id: string, props: FideeMediaWafStackProps) {
    super(scope, id, props);

    const stage = assertFideeStage(props.stage);
    applyStageTags(this, stage);

    const webAcl = new wafv2.CfnWebACL(this, 'MediaWebAcl', {
      name: resourceName(stage, 'media-waf'),
      scope: 'CLOUDFRONT',
      defaultAction: { allow: {} },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: resourceName(stage, 'media-waf'),
        sampledRequestsEnabled: true,
      },
      rules: webAclRules(stage),
    });

    this.webAclArn = webAcl.attrArn;

    new cdk.CfnOutput(this, 'MediaWebAclArn', {
      value: this.webAclArn,
    });
  }
}

export class FideeStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: FideeStackProps) {
    super(scope, id, props);

    const stage = assertFideeStage(props.stage);
    applyStageTags(this, stage);

    const removalPolicy = isProd(stage) ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY;

    // ─── Auth Trigger Lambdas (Custom Auth OTP Flow) ────────────
    const authTriggerDefaults: Omit<nodejs.NodejsFunctionProps, 'handler' | 'entry' | 'functionName'> = {
      runtime: lambda.Runtime.NODEJS_20_X,
      memorySize: 128,
      timeout: cdk.Duration.seconds(10),
    };

    const defineAuthChallengeFn = new nodejs.NodejsFunction(this, 'DefineAuthChallengeFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'define-auth'),
      entry: '../../services/api/src/triggers/define-auth-challenge.ts',
      handler: 'handler',
      environment: {
        GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID || '',
      },
    });

    const createAuthChallengeFn = new nodejs.NodejsFunction(this, 'CreateAuthChallengeFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'create-auth'),
      entry: '../../services/api/src/triggers/create-auth-challenge.ts',
      handler: 'handler',
      environment: {
        RESEND_API_KEY: process.env.RESEND_API_KEY || '',
        RESEND_SENDER_EMAIL: process.env.RESEND_SENDER_EMAIL || 'onboarding@resend.dev',
        GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID || '',
      },
    });

    // Grant SES send email
    createAuthChallengeFn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['ses:SendEmail'],
        resources: [`arn:aws:ses:${MAIN_REGION}:${cdk.Aws.ACCOUNT_ID}:identity/*`],
      }),
    );

    const verifyAuthChallengeFn = new nodejs.NodejsFunction(this, 'VerifyAuthChallengeFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'verify-auth'),
      entry: '../../services/api/src/triggers/verify-auth-challenge.ts',
      handler: 'handler',
      environment: {
        GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID || '',
      },
    });

    const preSignUpFn = new nodejs.NodejsFunction(this, 'PreSignUpFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'pre-sign-up'),
      entry: '../../services/api/src/triggers/pre-sign-up.ts',
      handler: 'handler',
    });

    // ─── Cognito User Pool ───────────────────────────────────────
    const userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: resourceName(stage, 'users'),
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      passwordPolicy: {
        minLength: 8,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: false,
      },
      lambdaTriggers: {
        defineAuthChallenge: defineAuthChallengeFn,
        createAuthChallenge: createAuthChallengeFn,
        verifyAuthChallengeResponse: verifyAuthChallengeFn,
        preSignUp: preSignUpFn,
      },
      removalPolicy,
    });



    // ─── Cognito Groups (RBAC) ───────────────────────────────────
    new cognito.CfnUserPoolGroup(this, 'UsersGroup', {
      groupName: 'Users',
      userPoolId: userPool.userPoolId,
      description: 'Default registered users',
    });
    new cognito.CfnUserPoolGroup(this, 'ModeratorsGroup', {
      groupName: 'Moderators',
      userPoolId: userPool.userPoolId,
      description: 'Content moderators',
    });
    new cognito.CfnUserPoolGroup(this, 'AdminsGroup', {
      groupName: 'Admins',
      userPoolId: userPool.userPoolId,
      description: 'Platform administrators',
    });

    const userPoolClient = userPool.addClient('WebClient', {
      authFlows: { userSrp: true, userPassword: true, custom: true },
    });

    const placesTable = new dynamodb.Table(this, 'PlacesTable', {
      tableName: resourceName(stage, 'places'),
      partitionKey: { name: 'PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'SK', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'expiresAt',
      removalPolicy,
    });

    const userProfilesTable = new dynamodb.Table(this, 'UserProfilesTable', {
      tableName: resourceName(stage, 'user-profiles'),
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'expiresAt',
      removalPolicy,
    });

    placesTable.addGlobalSecondaryIndex({
      indexName: 'GSI1',
      partitionKey: { name: 'GSI1PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'GSI1SK', type: dynamodb.AttributeType.STRING },
    });

    placesTable.addGlobalSecondaryIndex({
      indexName: 'GSI2',
      partitionKey: { name: 'GSI2PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'GSI2SK', type: dynamodb.AttributeType.STRING },
    });

    // ─── VPC (Private Isolated for Aurora — no NAT = $0) ────────
    const vpc = new ec2.Vpc(this, 'Vpc', {
      vpcName: resourceName(stage, 'vpc'),
      maxAzs: 2,
      natGateways: 0,
      subnetConfiguration: [
        {
          name: 'isolated',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
    });

    // VPC Endpoints — required for Lambda in isolated subnets
    vpc.addGatewayEndpoint('DynamoDbEndpoint', {
      service: ec2.GatewayVpcEndpointAwsService.DYNAMODB,
    });
    vpc.addGatewayEndpoint('S3Endpoint', {
      service: ec2.GatewayVpcEndpointAwsService.S3,
    });
    vpc.addInterfaceEndpoint('SecretsManagerEndpoint', {
      service: ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
    });

    // ─── Aurora Serverless v2 (PostgreSQL 16.4) ─────────────────
    const dbSecurityGroup = new ec2.SecurityGroup(this, 'DbSecurityGroup', {
      securityGroupName: resourceName(stage, 'db-sg'),
      vpc,
      description: 'Security group for Aurora PostgreSQL',
      allowAllOutbound: false,
    });

    const dbCluster = new rds.DatabaseCluster(this, 'Database', {
      clusterIdentifier: resourceName(stage, 'db'),
      engine: rds.DatabaseClusterEngine.auroraPostgres({
        version: rds.AuroraPostgresEngineVersion.VER_16_4,
      }),
      serverlessV2MinCapacity: 0.5,
      serverlessV2MaxCapacity: isProd(stage) ? 8 : 2,
      writer: rds.ClusterInstance.serverlessV2('writer', {
        publiclyAccessible: false,
      }),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [dbSecurityGroup],
      defaultDatabaseName: 'fidee',
      removalPolicy,
      storageEncrypted: true,
      backup: {
        retention: isProd(stage) ? cdk.Duration.days(7) : cdk.Duration.days(1),
      },
    });

    // Lambda security group — allows Lambda to connect to Aurora
    const lambdaSecurityGroup = new ec2.SecurityGroup(this, 'LambdaSecurityGroup', {
      securityGroupName: resourceName(stage, 'lambda-sg'),
      vpc,
      description: 'Security group for Lambda functions accessing Aurora',
      allowAllOutbound: true,
    });

    dbSecurityGroup.addIngressRule(
      lambdaSecurityGroup,
      ec2.Port.tcp(5432),
      'Allow Lambda to connect to Aurora PostgreSQL',
    );

    const mediaBucket = new s3.Bucket(this, 'MediaBucket', {
      bucketName: `${resourceName(stage, 'media')}-${cdk.Aws.ACCOUNT_ID}-${MAIN_REGION}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy,
      autoDeleteObjects: !isProd(stage),
    });
    mediaBucket.enableEventBridgeNotification();

    const mediaDistribution = new cloudfront.Distribution(this, 'MediaDistribution', {
      comment: resourceName(stage, 'media'),
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(mediaBucket),
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
        cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      },
      priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
      webAclId: props.mediaWebAclArn,
    });

    const searchFunctionName = resourceName(stage, 'search');
    const searchLogGroup = new logs.LogGroup(this, 'SearchLogGroup', {
      logGroupName: `/aws/lambda/${searchFunctionName}`,
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy,
    });

    const searchRole = new iam.Role(this, 'SearchFunctionRole', {
      roleName: resourceName(stage, 'search-role'),
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      inlinePolicies: {
        SearchFunctionPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: ['logs:CreateLogStream', 'logs:PutLogEvents'],
              resources: [`${searchLogGroup.logGroupArn}:*`],
            }),
            new iam.PolicyStatement({
              actions: [
                'dynamodb:BatchGetItem',
                'dynamodb:ConditionCheckItem',
                'dynamodb:DescribeTable',
                'dynamodb:GetItem',
                'dynamodb:Query',
                'dynamodb:Scan',
              ],
              resources: [placesTable.tableArn, `${placesTable.tableArn}/index/GSI1`],
            }),
          ],
        }),
      },
    });

    const searchFn = new lambda.Function(this, 'SearchFunction', {
      functionName: searchFunctionName,
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'handlers/search.handler',
      code: lambda.Code.fromAsset('../../services/api/dist'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(30),
      logGroup: searchLogGroup,
      role: searchRole,
      environment: {
        STAGE: stage,
        PLACES_TABLE: placesTable.tableName,
        MEDIA_BUCKET: mediaBucket.bucketName,
        MEDIA_DISTRIBUTION_DOMAIN_NAME: mediaDistribution.distributionDomainName,
      },
    });

    const createMediaUploadFn = new nodejs.NodejsFunction(this, 'CreateMediaUploadFunction', {
      functionName: resourceName(stage, 'create-media-upload'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-media-upload.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        MEDIA_BUCKET: mediaBucket.bucketName,
        USER_PROFILES_TABLE: userProfilesTable.tableName,
        UPLOAD_EXPIRY_SECONDS: '300',
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(createMediaUploadFn);
    userProfilesTable.grantReadWriteData(createMediaUploadFn);
    mediaBucket.grantPut(createMediaUploadFn, 'uploads/*');

    const mediaUploadEventsDlq = new sqs.Queue(this, 'MediaUploadEventsDlq', {
      queueName: resourceName(stage, 'media-upload-events-dlq'),
      retentionPeriod: cdk.Duration.days(14),
    });

    const mediaUploadEventsQueue = new sqs.Queue(this, 'MediaUploadEventsQueue', {
      queueName: resourceName(stage, 'media-upload-events'),
      retentionPeriod: cdk.Duration.days(4),
      visibilityTimeout: cdk.Duration.seconds(90),
      deadLetterQueue: {
        queue: mediaUploadEventsDlq,
        maxReceiveCount: 3,
      },
    });

    const handleMediaUploadedFn = new lambda.Function(this, 'HandleMediaUploadedFunction', {
      functionName: resourceName(stage, 'handle-media-uploaded'),
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'handlers/handle-media-uploaded.handler',
      code: lambda.Code.fromAsset('../../services/api/dist'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(30),
      environment: {
        STAGE: stage,
        PLACES_TABLE: placesTable.tableName,
        MEDIA_BUCKET: mediaBucket.bucketName,
      },
    });
    mediaBucket.grantRead(handleMediaUploadedFn, 'uploads/*');
    placesTable.grantWriteData(handleMediaUploadedFn);
    mediaUploadEventsQueue.grantConsumeMessages(handleMediaUploadedFn);
    handleMediaUploadedFn.addEventSource(
      new lambdaEventSources.SqsEventSource(mediaUploadEventsQueue, { batchSize: 10 }),
    );

    const rootDomain = 'fidee.site';
    const apiDomainName = `api.${rootDomain}`;

    const hostedZone = route53.HostedZone.fromLookup(this, 'HostedZone', {
      domainName: rootDomain,
    });

    const apiCertificate = new acm.Certificate(this, 'ApiCertificate', {
      domainName: apiDomainName,
      validation: acm.CertificateValidation.fromDns(hostedZone),
    });

    const api = new apigateway.RestApi(this, 'Api', {
      restApiName: resourceName(stage, 'api'),
      deployOptions: {
        stageName: stage,
        metricsEnabled: true,
      },
      domainName: {
        domainName: apiDomainName,
        certificate: apiCertificate,
      },
    });

    // Cấu hình Gateway Responses để hỗ trợ CORS cho các lỗi 4XX và 5XX
    api.addGatewayResponse('Default4XX', {
      type: apigateway.ResponseType.DEFAULT_4XX,
      responseHeaders: {
        'gatewayresponse.header.Access-Control-Allow-Origin': "'*'",
        'gatewayresponse.header.Access-Control-Allow-Headers': "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        'gatewayresponse.header.Access-Control-Allow-Methods': "'GET,POST,PUT,DELETE,OPTIONS'",
      },
    });

    api.addGatewayResponse('Default5XX', {
      type: apigateway.ResponseType.DEFAULT_5XX,
      responseHeaders: {
        'gatewayresponse.header.Access-Control-Allow-Origin': "'*'",
        'gatewayresponse.header.Access-Control-Allow-Headers': "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        'gatewayresponse.header.Access-Control-Allow-Methods': "'GET,POST,PUT,DELETE,OPTIONS'",
      },
    });

    new route53.ARecord(this, 'ApiAliasRecord', {
      zone: hostedZone,
      recordName: apiDomainName,
      target: route53.RecordTarget.fromAlias(new route53Targets.ApiGateway(api)),
    });

    // ─── Cognito JWT Authorizer ─────────────────────────────────
    const cognitoAuthorizer = new apigateway.CognitoUserPoolsAuthorizer(this, 'CognitoAuth', {
      cognitoUserPools: [userPool],
      identitySource: 'method.request.header.Authorization',
    });

    const searchResource = api.root.addResource('search');
    searchResource.addMethod('POST', new apigateway.LambdaIntegration(searchFn));

    // ─── GET /profile (protected) ────────────────────────────────
    const profileFn = new nodejs.NodejsFunction(this, 'GetProfileFunction', {
      functionName: resourceName(stage, 'get-profile'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-profile.ts',
      handler: 'handler',
      memorySize: 128,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
        USER_PROFILES_TABLE: userProfilesTable.tableName,
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(profileFn);
    userProfilesTable.grantReadWriteData(profileFn);

    const profileResource = api.root.addResource('profile');
    profileResource.addMethod('GET', new apigateway.LambdaIntegration(profileFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const mediaResource = api.root.addResource('media');
    const mediaUploadsResource = mediaResource.addResource('uploads');
    mediaUploadsResource.addMethod('POST', new apigateway.LambdaIntegration(createMediaUploadFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── POST /place-candidates (protected) ─────────────────────
    const createPlaceCandidateFn = new nodejs.NodejsFunction(this, 'CreatePlaceCandidateFunction', {
      functionName: resourceName(stage, 'create-place-candidate'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-place-candidate.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(15),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        PLACES_TABLE: placesTable.tableName,
        MEDIA_BUCKET: mediaBucket.bucketName,
        USER_PROFILES_TABLE: userProfilesTable.tableName,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(createPlaceCandidateFn);
    placesTable.grantReadWriteData(createPlaceCandidateFn);
    userProfilesTable.grantReadWriteData(createPlaceCandidateFn);
    mediaBucket.grantRead(createPlaceCandidateFn, 'uploads/*');

    const placeCandidatesResource = api.root.addResource('place-candidates');
    placeCandidatesResource.addMethod('POST',
      new apigateway.LambdaIntegration(createPlaceCandidateFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    },
    );

    // ─── DB Migration Lambda (VPC, connects to Aurora) ──────────
    const migrateFn = new nodejs.NodejsFunction(this, 'MigrateFunction', {
      functionName: resourceName(stage, 'db-migrate'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/db/migrate.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(60),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(migrateFn);

    // ─── GET /map/feed (protected) ──────────────────────────────
    const getMapFeedFn = new nodejs.NodejsFunction(this, 'GetMapFeedFunction', {
      functionName: resourceName(stage, 'get-map-feed'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-map-feed.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(getMapFeedFn);

    const mapResource = api.root.addResource('map');
    const mapFeedResource = mapResource.addResource('feed');
    mapFeedResource.addMethod('GET', new apigateway.LambdaIntegration(getMapFeedFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /places/nearby (protected) ─────────────────────────
    const getNearbyPlacesFn = new nodejs.NodejsFunction(this, 'GetNearbyPlacesFunction', {
      functionName: resourceName(stage, 'get-nearby-places'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-nearby-places.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(getNearbyPlacesFn);

    // ─── GET /admin/users (VPC, connects to Aurora) ────────────
    const getUsersFn = new nodejs.NodejsFunction(this, 'GetUsersFunction', {
      functionName: resourceName(stage, 'get-users'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-users.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(getUsersFn);

    // ─── PUT /admin/users/{userId} (VPC, connects to Aurora) ────
    const updateUserFn = new nodejs.NodejsFunction(this, 'UpdateUserFunction', {
      functionName: resourceName(stage, 'update-user'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/update-user.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
        USER_PROFILES_TABLE: userProfilesTable.tableName,
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(updateUserFn);
    userProfilesTable.grantReadWriteData(updateUserFn);

    const placesResource = api.root.addResource('places');
    const nearbyResource = placesResource.addResource('nearby');
    nearbyResource.addMethod('GET', new apigateway.LambdaIntegration(getNearbyPlacesFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── Admin Users Resources (protected) ──────────────────────
    const adminResource = api.root.addResource('admin');
    const adminUsersResource = adminResource.addResource('users');

    // Add CORS Preflight options for web browser clients
    adminUsersResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });

    adminUsersResource.addMethod('GET', new apigateway.LambdaIntegration(getUsersFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const adminUserDetailResource = adminUsersResource.addResource('{userId}');
    // Add CORS Preflight options for web browser clients
    adminUserDetailResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['PUT', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });

    adminUserDetailResource.addMethod('PUT', new apigateway.LambdaIntegration(updateUserFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── Admin Places Review APIs ────────────────────────────────

    // Shared Lambda config for admin place handlers
    const adminLambdaProps = {
      runtime: lambda.Runtime.NODEJS_20_X,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    };

    // GET /admin/places/pending
    const getPendingPlacesFn = new nodejs.NodejsFunction(this, 'GetPendingPlacesFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'get-pending-places'),
      entry: '../../services/api/src/handlers/admin/get-pending-places.ts',
      handler: 'handler',
    });
    dbCluster.secret!.grantRead(getPendingPlacesFn);

    // GET /admin/places/candidates/{id}
    const getCandidateDetailFn = new nodejs.NodejsFunction(this, 'GetCandidateDetailFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'get-candidate-detail'),
      entry: '../../services/api/src/handlers/admin/get-candidate-detail.ts',
      handler: 'handler',
    });
    dbCluster.secret!.grantRead(getCandidateDetailFn);

    // POST /admin/places/candidates/{id}/approve
    const approveCandidateFn = new nodejs.NodejsFunction(this, 'ApproveCandidateFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'approve-candidate'),
      entry: '../../services/api/src/handlers/admin/approve-candidate.ts',
      handler: 'handler',
    });
    dbCluster.secret!.grantRead(approveCandidateFn);

    // POST /admin/places/candidates/{id}/reject
    const rejectCandidateFn = new nodejs.NodejsFunction(this, 'RejectCandidateFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'reject-candidate'),
      entry: '../../services/api/src/handlers/admin/reject-candidate.ts',
      handler: 'handler',
    });
    dbCluster.secret!.grantRead(rejectCandidateFn);

    // POST /admin/places/candidates/{id}/merge
    const mergeCandidateFn = new nodejs.NodejsFunction(this, 'MergeCandidateFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'merge-candidate'),
      entry: '../../services/api/src/handlers/admin/merge-candidate.ts',
      handler: 'handler',
    });
    dbCluster.secret!.grantRead(mergeCandidateFn);

    // ─── Admin Places API Resources ─────────────────────────────
    const adminPlacesResource = adminResource.addResource('places');

    // /admin/places/pending
    const adminPendingResource = adminPlacesResource.addResource('pending');
    adminPendingResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminPendingResource.addMethod('GET', new apigateway.LambdaIntegration(getPendingPlacesFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // /admin/places/candidates/{id}
    const adminCandidatesResource = adminPlacesResource.addResource('candidates');
    const adminCandidateDetailResource = adminCandidatesResource.addResource('{id}');
    adminCandidateDetailResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminCandidateDetailResource.addMethod('GET', new apigateway.LambdaIntegration(getCandidateDetailFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // /admin/places/candidates/{id}/approve
    const adminApproveResource = adminCandidateDetailResource.addResource('approve');
    adminApproveResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminApproveResource.addMethod('POST', new apigateway.LambdaIntegration(approveCandidateFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // /admin/places/candidates/{id}/reject
    const adminRejectResource = adminCandidateDetailResource.addResource('reject');
    adminRejectResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminRejectResource.addMethod('POST', new apigateway.LambdaIntegration(rejectCandidateFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // /admin/places/candidates/{id}/merge
    const adminMergeResource = adminCandidateDetailResource.addResource('merge');
    adminMergeResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminMergeResource.addMethod('POST', new apigateway.LambdaIntegration(mergeCandidateFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const mediaUploadObjectCreatedRule = new events.Rule(this, 'MediaUploadObjectCreatedRule', {
      ruleName: resourceName(stage, 'media-upload-object-created'),
      eventPattern: {
        source: ['aws.s3'],
        detailType: ['Object Created'],
        detail: {
          bucket: {
            name: [mediaBucket.bucketName],
          },
          object: {
            key: [{ prefix: 'uploads/' }],
          },
        },
      },
    });
    mediaUploadObjectCreatedRule.addTarget(new targets.SqsQueue(mediaUploadEventsQueue));

    const apiWebAcl = new wafv2.CfnWebACL(this, 'ApiWebAcl', {
      name: resourceName(stage, 'api-waf'),
      scope: 'REGIONAL',
      defaultAction: { allow: {} },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: resourceName(stage, 'api-waf'),
        sampledRequestsEnabled: true,
      },
      rules: webAclRules(stage),
    });

    const apiWebAclAssociation = new wafv2.CfnWebACLAssociation(this, 'ApiWebAclAssociation', {
      resourceArn: cdk.Fn.join('', [
        'arn:',
        cdk.Aws.PARTITION,
        ':apigateway:',
        cdk.Aws.REGION,
        '::/restapis/',
        api.restApiId,
        '/stages/',
        api.deploymentStage.stageName,
      ]),
      webAclArn: apiWebAcl.attrArn,
    });
    const apiStage = api.deploymentStage.node.defaultChild;
    if (apiStage instanceof cdk.CfnResource) {
      apiWebAclAssociation.addDependency(apiStage);
    }

    new cdk.CfnOutput(this, 'ApiUrl', { value: api.url });
    new cdk.CfnOutput(this, 'CustomApiUrl', { value: `https://${apiDomainName}/` });
    new cdk.CfnOutput(this, 'UserPoolId', { value: userPool.userPoolId });
    new cdk.CfnOutput(this, 'UserPoolClientId', { value: userPoolClient.userPoolClientId });
    new cdk.CfnOutput(this, 'PlacesTableName', { value: placesTable.tableName });
    new cdk.CfnOutput(this, 'UserProfilesTableName', { value: userProfilesTable.tableName });
    new cdk.CfnOutput(this, 'MediaUploadEventsQueueUrl', {
      value: mediaUploadEventsQueue.queueUrl,
    });
    new cdk.CfnOutput(this, 'MediaBucketName', { value: mediaBucket.bucketName });
    new cdk.CfnOutput(this, 'MediaDistributionDomainName', {
      value: mediaDistribution.distributionDomainName,
    });
    new cdk.CfnOutput(this, 'ApiWebAclArn', { value: apiWebAcl.attrArn });
    new cdk.CfnOutput(this, 'MediaWebAclArn', { value: props.mediaWebAclArn });
    new cdk.CfnOutput(this, 'VpcId', { value: vpc.vpcId });
    new cdk.CfnOutput(this, 'DbClusterEndpoint', { value: dbCluster.clusterEndpoint.hostname });
    new cdk.CfnOutput(this, 'DbSecretArn', { value: dbCluster.secret!.secretArn });
  }
}
