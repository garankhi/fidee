import * as cdk from 'aws-cdk-lib';
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
    const authTriggerDefaults: Omit<lambda.FunctionProps, 'handler' | 'functionName'> = {
      runtime: lambda.Runtime.NODEJS_20_X,
      code: lambda.Code.fromAsset('../../services/api/dist'),
      memorySize: 128,
      timeout: cdk.Duration.seconds(10),
    };

    const defineAuthChallengeFn = new lambda.Function(this, 'DefineAuthChallengeFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'define-auth'),
      handler: 'triggers/define-auth-challenge.handler',
    });

    const createAuthChallengeFn = new lambda.Function(this, 'CreateAuthChallengeFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'create-auth'),
      handler: 'triggers/create-auth-challenge.handler',
      environment: {
        RESEND_API_KEY: process.env.RESEND_API_KEY || '', RESEND_SENDER_EMAIL: process.env.RESEND_SENDER_EMAIL || 'onboarding@resend.dev', },
    });

    // Grant SES send email
    createAuthChallengeFn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['ses:SendEmail'],
        resources: [`arn:aws:ses:${MAIN_REGION}:${cdk.Aws.ACCOUNT_ID}:identity/*`],
      }),
    );

    const verifyAuthChallengeFn = new lambda.Function(this, 'VerifyAuthChallengeFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'verify-auth'),
      handler: 'triggers/verify-auth-challenge.handler',
    });

    const preSignUpFn = new lambda.Function(this, 'PreSignUpFn', {
      ...authTriggerDefaults,
      functionName: resourceName(stage, 'pre-sign-up'),
      handler: 'triggers/pre-sign-up.handler',
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
      authFlows: { userSrp: true, userPassword: true },
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

    const createMediaUploadFn = new lambda.Function(this, 'CreateMediaUploadFunction', {
      functionName: resourceName(stage, 'create-media-upload'),
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'handlers/create-media-upload.handler',
      code: lambda.Code.fromAsset('../../services/api/dist'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      environment: {
        STAGE: stage,
        MEDIA_BUCKET: mediaBucket.bucketName,
        USER_PROFILES_TABLE: userProfilesTable.tableName,
        UPLOAD_EXPIRY_SECONDS: '300',
      },
    });
    userProfilesTable.grantReadData(createMediaUploadFn);
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

    const api = new apigateway.RestApi(this, 'Api', {
      restApiName: resourceName(stage, 'api'),
      deployOptions: {
        stageName: stage,
        metricsEnabled: true,
      },
    });

    // ─── Cognito JWT Authorizer ─────────────────────────────────
    const cognitoAuthorizer = new apigateway.CognitoUserPoolsAuthorizer(this, 'CognitoAuth', {
      cognitoUserPools: [userPool],
      identitySource: 'method.request.header.Authorization',
    });

    const searchResource = api.root.addResource('search');
    searchResource.addMethod('POST', new apigateway.LambdaIntegration(searchFn));

    // ─── GET /profile (protected) ────────────────────────────────
    const profileFn = new lambda.Function(this, 'GetProfileFunction', {
      functionName: resourceName(stage, 'get-profile'),
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'handlers/get-profile.handler',
      code: lambda.Code.fromAsset('../../services/api/dist'),
      memorySize: 128,
      timeout: cdk.Duration.seconds(10),
      environment: { STAGE: stage },
    });

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
    const createPlaceCandidateFn = new lambda.Function(this, 'CreatePlaceCandidateFunction', {
      functionName: resourceName(stage, 'create-place-candidate'),
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'handlers/create-place-candidate.handler',
      code: lambda.Code.fromAsset('../../services/api/dist'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(15),
      environment: {
        STAGE: stage,
        PLACES_TABLE: placesTable.tableName,
        MEDIA_BUCKET: mediaBucket.bucketName,
        USER_PROFILES_TABLE: userProfilesTable.tableName,
      },
    });
    placesTable.grantReadWriteData(createPlaceCandidateFn);
    userProfilesTable.grantReadData(createPlaceCandidateFn);
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
    });
    dbCluster.secret!.grantRead(getMapFeedFn);

    const mapResource = api.root.addResource('map');
    const mapFeedResource = mapResource.addResource('feed');
    mapFeedResource.addMethod('GET', new apigateway.LambdaIntegration(getMapFeedFn), {
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
