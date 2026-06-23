import * as cdk from 'aws-cdk-lib';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as appsync from 'aws-cdk-lib/aws-appsync';
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
import { ChatApiStack } from './nested/chat-api-stack';
import { AdminApiStack } from './nested/admin-api-stack';

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

    const lambdaBasicExecutionPolicy = iam.ManagedPolicy.fromAwsManagedPolicyName(
      'service-role/AWSLambdaBasicExecutionRole',
    );
    const lambdaVpcExecutionPolicy = iam.ManagedPolicy.fromAwsManagedPolicyName(
      'service-role/AWSLambdaVPCAccessExecutionRole',
    );

    const createSharedLambdaRole = (
      roleId: string,
      roleNameSuffix: string,
      options: { vpcAccess?: boolean } = {},
    ) =>
      new iam.Role(this, roleId, {
        roleName: resourceName(stage, roleNameSuffix),
        assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
        managedPolicies: [
          lambdaBasicExecutionPolicy,
          ...(options.vpcAccess === false ? [] : [lambdaVpcExecutionPolicy]),
        ],
      });

    // ─── Auth Trigger Lambdas (Custom Auth OTP Flow) ────────────
    const authTriggerDefaults: Omit<
      nodejs.NodejsFunctionProps,
      'handler' | 'entry' | 'functionName'
    > = {
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
      bundling: {
        nodeModules: ['resend'],
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

    const friendRealtimeApi = new appsync.GraphqlApi(this, 'FriendRealtimeApi', {
      name: resourceName(stage, 'friend-realtime'),
      definition: appsync.Definition.fromFile('graphql/friend-realtime.graphql'),
      authorizationConfig: {
        defaultAuthorization: {
          authorizationType: appsync.AuthorizationType.USER_POOL,
          userPoolConfig: { userPool },
        },
        additionalAuthorizationModes: [{ authorizationType: appsync.AuthorizationType.IAM }],
      },
      logConfig: {
        fieldLogLevel: appsync.FieldLogLevel.ERROR,
        retention: logs.RetentionDays.ONE_WEEK,
      },
      xrayEnabled: !isProd(stage),
    });

    const friendRealtimeNoneDataSource = friendRealtimeApi.addNoneDataSource(
      'FriendRealtimeNoneDataSource',
    );

    friendRealtimeNoneDataSource.createResolver('PublishFriendRequestReceivedResolver', {
      typeName: 'Mutation',
      fieldName: 'publishFriendRequestReceived',
      requestMappingTemplate: appsync.MappingTemplate.fromString(
        '{"version":"2018-05-29","payload":$util.toJson($ctx.args.input)}',
      ),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson($ctx.result)'),
    });

    friendRealtimeNoneDataSource.createResolver('PublishFriendRequestCanceledResolver', {
      typeName: 'Mutation',
      fieldName: 'publishFriendRequestCanceled',
      requestMappingTemplate: appsync.MappingTemplate.fromString(
        '{"version":"2018-05-29","payload":$util.toJson($ctx.args.input)}',
      ),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson($ctx.result)'),
    });

    friendRealtimeNoneDataSource.createResolver('PublishFriendRealtimeEventResolver', {
      typeName: 'Mutation',
      fieldName: 'publishFriendRealtimeEvent',
      requestMappingTemplate: appsync.MappingTemplate.fromString(
        '{"version":"2018-05-29","payload":$util.toJson($ctx.args.input)}',
      ),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson($ctx.result)'),
    });

    friendRealtimeNoneDataSource.createResolver('PublishChatRealtimeEventResolver', {
      typeName: 'Mutation',
      fieldName: 'publishChatRealtimeEvent',
      requestMappingTemplate: appsync.MappingTemplate.fromString(
        '{"version":"2018-05-29","payload":$util.toJson($ctx.args.input)}',
      ),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson($ctx.result)'),
    });

    friendRealtimeNoneDataSource.createResolver('OnFriendRealtimeEventResolver', {
      typeName: 'Subscription',
      fieldName: 'onFriendRealtimeEvent',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
#if($ctx.identity.sub != $ctx.args.targetUserId)
  $util.unauthorized()
#end
{"version":"2018-05-29","payload":null}
`),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson(null)'),
    });

    friendRealtimeNoneDataSource.createResolver('OnFriendRequestReceivedResolver', {
      typeName: 'Subscription',
      fieldName: 'onFriendRequestReceived',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
#if($ctx.identity.sub != $ctx.args.targetUserId)
  $util.unauthorized()
#end
{"version":"2018-05-29","payload":null}
`),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson(null)'),
    });

    friendRealtimeNoneDataSource.createResolver('OnFriendRequestCanceledResolver', {
      typeName: 'Subscription',
      fieldName: 'onFriendRequestCanceled',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
#if($ctx.identity.sub != $ctx.args.targetUserId)
  $util.unauthorized()
#end
{"version":"2018-05-29","payload":null}
`),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson(null)'),
    });

    friendRealtimeNoneDataSource.createResolver('OnChatRealtimeEventResolver', {
      typeName: 'Subscription',
      fieldName: 'onChatRealtimeEvent',
      requestMappingTemplate: appsync.MappingTemplate.fromString(`
#if($ctx.identity.sub != $ctx.args.targetUserId)
  $util.unauthorized()
#end
{"version":"2018-05-29","payload":null}
`),
      responseMappingTemplate: appsync.MappingTemplate.fromString('$util.toJson(null)'),
    });

    new cdk.CfnOutput(this, 'FriendRealtimeGraphqlUrl', {
      value: friendRealtimeApi.graphqlUrl,
    });
    new cdk.CfnOutput(this, 'FriendRealtimeApiId', {
      value: friendRealtimeApi.apiId,
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

    const friendRequestRealtimeEventsTable = new dynamodb.Table(
      this,
      'FriendRequestRealtimeEventsTable',
      {
        tableName: resourceName(stage, 'friend-request-realtime-events'),
        partitionKey: { name: 'eventId', type: dynamodb.AttributeType.STRING },
        billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
        stream: dynamodb.StreamViewType.NEW_IMAGE,
        timeToLiveAttribute: 'expiresAt',
        removalPolicy,
      },
    );

    const chatRealtimeEventsTable = new dynamodb.Table(this, 'ChatRealtimeEventsTable', {
      tableName: resourceName(stage, 'chat-realtime-events'),
      partitionKey: { name: 'eventId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      stream: dynamodb.StreamViewType.NEW_IMAGE,
      timeToLiveAttribute: 'expiresAt',
      removalPolicy,
    });

    const chatPresenceTable = new dynamodb.Table(this, 'ChatPresenceTable', {
      tableName: resourceName(stage, 'chat-presence'),
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

    // ─── VPC ─────────────────────────────────────────────────────
    // natGateways: 1 enables internet egress for Lambdas in
    // PRIVATE_WITH_EGRESS subnet (needed for calling external APIs
    // like OpenAI). Cost: ~$32/month. Set to 0 if not needed.
    const vpc = new ec2.Vpc(this, 'Vpc', {
      vpcName: resourceName(stage, 'vpc'),
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        {
          name: 'isolated',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
        {
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'private-egress',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
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

    // ─── Bastion Host (For Local Database Access) ───────────
    const bastion = new ec2.BastionHostLinux(this, 'BastionHost', {
      vpc,
      subnetSelection: { subnetType: ec2.SubnetType.PUBLIC },
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T4G, ec2.InstanceSize.NANO),
      machineImage: ec2.MachineImage.latestAmazonLinux2023({
        cpuType: ec2.AmazonLinuxCpuType.ARM_64,
      }),
    });

    dbSecurityGroup.addIngressRule(
      bastion.connections.securityGroups[0],
      ec2.Port.tcp(5432),
      'Allow Bastion Host to connect to Aurora PostgreSQL',
    );

    new cdk.CfnOutput(this, 'BastionHostId', {
      value: bastion.instanceId,
    });

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

    const friendsApiLambdaRole = createSharedLambdaRole('FriendsApiLambdaRole', 'friends-api-role');
    dbCluster.secret!.grantRead(friendsApiLambdaRole);
    friendRequestRealtimeEventsTable.grantWriteData(friendsApiLambdaRole);


    const billingApiLambdaRole = createSharedLambdaRole('BillingApiLambdaRole', 'billing-api-role');
    dbCluster.secret!.grantRead(billingApiLambdaRole);
    userProfilesTable.grantReadWriteData(billingApiLambdaRole);

    const placeCandidateApiLambdaRole = createSharedLambdaRole(
      'PlaceCandidateApiLambdaRole',
      'place-candidate-api-role',
    );
    dbCluster.secret!.grantRead(placeCandidateApiLambdaRole);
    placesTable.grantReadWriteData(placeCandidateApiLambdaRole);
    userProfilesTable.grantReadWriteData(placeCandidateApiLambdaRole);
    mediaBucket.grantRead(placeCandidateApiLambdaRole, 'uploads/*');

    const placesApiLambdaRole = createSharedLambdaRole('PlacesApiLambdaRole', 'places-api-role');
    dbCluster.secret!.grantRead(placesApiLambdaRole);


    const mediaUploadApiLambdaRole = createSharedLambdaRole(
      'MediaUploadApiLambdaRole',
      'media-upload-api-role',
    );
    dbCluster.secret!.grantRead(mediaUploadApiLambdaRole);
    userProfilesTable.grantReadWriteData(mediaUploadApiLambdaRole);
    mediaBucket.grantPut(mediaUploadApiLambdaRole, 'uploads/*');
    mediaBucket.grantPut(mediaUploadApiLambdaRole, 'avatars/*');

    // ─── Search Lambda (AI Chat — needs VPC for DB + internet for LLM) ──
    const searchFn = new nodejs.NodejsFunction(this, 'SearchFunction', {
      functionName: resourceName(stage, 'search'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/search.ts',
      handler: 'handler',
      memorySize: 512,
      timeout: cdk.Duration.seconds(60),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        USER_PROFILES_TABLE: userProfilesTable.tableName,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
        LLM_PROVIDER: 'gemini',
        GEMINI_API_KEYS: process.env.GEMINI_API_KEYS || process.env.GEMINI_API_KEY || '',
        GEMINI_MODEL: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
        BEDROCK_MODEL_ID: process.env.BEDROCK_MODEL_ID || '',
        BEDROCK_REGION: process.env.BEDROCK_REGION || 'ap-northeast-1',
      },
      bundling: {
        nodeModules: ['pg', 'openai', '@google/genai'],
      },
    });
    dbCluster.secret!.grantRead(searchFn);
    userProfilesTable.grantReadWriteData(searchFn);

    const createMediaUploadFn = new nodejs.NodejsFunction(this, 'CreateMediaUploadFunction', {
      functionName: resourceName(stage, 'create-media-upload'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-media-upload.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: mediaUploadApiLambdaRole,
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

    // === POST /media/avatar (no GPS upload) ===
    const createAvatarUploadFn = new nodejs.NodejsFunction(this, 'CreateAvatarUploadFunction', {
      functionName: resourceName(stage, 'create-avatar-upload'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-avatar-upload.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: mediaUploadApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        MEDIA_BUCKET: mediaBucket.bucketName,
        UPLOAD_EXPIRY_SECONDS: '300',
        MEDIA_DISTRIBUTION_DOMAIN_NAME: mediaDistribution.distributionDomainName,
      },
    });

    const getMediaFn = new nodejs.NodejsFunction(this, 'GetMediaFunction', {
      functionName: resourceName(stage, 'get-media'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-media.ts',
      handler: 'handler',
      memorySize: 128,
      timeout: cdk.Duration.seconds(10),
      environment: {
        STAGE: stage,
        PLACES_TABLE: placesTable.tableName,
        MEDIA_DISTRIBUTION_DOMAIN_NAME: mediaDistribution.distributionDomainName,
      },
    });
    placesTable.grantReadData(getMediaFn);

    // === Friends Lambda Handlers ===
    const friendsLambdaProps = {
      runtime: lambda.Runtime.NODEJS_20_X,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: friendsApiLambdaRole,
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

    const getFriendsFn = new nodejs.NodejsFunction(this, 'GetFriendsFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'get-friends'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'getFriends',
    });

    const getFriendRequestsFn = new nodejs.NodejsFunction(this, 'GetFriendRequestsFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'get-friend-requests'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'getFriendRequests',
    });

    const getSentFriendRequestsFn = new nodejs.NodejsFunction(
      this,
      'GetSentFriendRequestsFunction',
      {
        ...friendsLambdaProps,
        functionName: resourceName(stage, 'get-sent-friend-requests'),
        entry: '../../services/api/src/handlers/friends-handlers.ts',
        handler: 'getSentFriendRequests',
      },
    );

    const sendFriendRequestFn = new nodejs.NodejsFunction(this, 'SendFriendRequestFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'send-friend-request'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'sendFriendRequest',
      environment: {
        ...friendsLambdaProps.environment,
        FRIEND_REQUEST_REALTIME_EVENTS_TABLE: friendRequestRealtimeEventsTable.tableName,
      },
    });

    const cancelFriendRequestFn = new nodejs.NodejsFunction(this, 'CancelFriendRequestFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'cancel-friend-request'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'cancelFriendRequest',
      environment: {
        ...friendsLambdaProps.environment,
        FRIEND_REQUEST_REALTIME_EVENTS_TABLE: friendRequestRealtimeEventsTable.tableName,
      },
    });

    const acceptFriendFn = new nodejs.NodejsFunction(this, 'AcceptFriendFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'accept-friend'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'acceptFriend',
      environment: {
        ...friendsLambdaProps.environment,
        FRIEND_REQUEST_REALTIME_EVENTS_TABLE: friendRequestRealtimeEventsTable.tableName,
      },
    });

    const declineFriendFn = new nodejs.NodejsFunction(this, 'DeclineFriendFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'decline-friend'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'declineFriend',
      environment: {
        ...friendsLambdaProps.environment,
        FRIEND_REQUEST_REALTIME_EVENTS_TABLE: friendRequestRealtimeEventsTable.tableName,
      },
    });

    const unfriendFn = new nodejs.NodejsFunction(this, 'UnfriendFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'unfriend'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'unfriend',
      environment: {
        ...friendsLambdaProps.environment,
        FRIEND_REQUEST_REALTIME_EVENTS_TABLE: friendRequestRealtimeEventsTable.tableName,
      },
    });
    const searchFriendsFn = new nodejs.NodejsFunction(this, 'SearchFriendsFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'search-friends'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'searchUsersByUsername',
    });

    const hideFriendFn = new nodejs.NodejsFunction(this, 'HideFriendFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'hide-friend'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'hideFriend',
      environment: {
        ...friendsLambdaProps.environment,
        FRIEND_REQUEST_REALTIME_EVENTS_TABLE: friendRequestRealtimeEventsTable.tableName,
      },
    });

    const blockFriendFn = new nodejs.NodejsFunction(this, 'BlockFriendFunction', {
      ...friendsLambdaProps,
      functionName: resourceName(stage, 'block-friend'),
      entry: '../../services/api/src/handlers/friends-handlers.ts',
      handler: 'blockFriend',
      environment: {
        ...friendsLambdaProps.environment,
        FRIEND_REQUEST_REALTIME_EVENTS_TABLE: friendRequestRealtimeEventsTable.tableName,
      },
    });

    const publishFriendRealtimeEventFn = new nodejs.NodejsFunction(
      this,
      'PublishFriendRealtimeEventFunction',
      {
        functionName: resourceName(stage, 'publish-friend-realtime-event'),
        runtime: lambda.Runtime.NODEJS_20_X,
        entry: '../../services/api/src/handlers/publish-friend-realtime-event.ts',
        handler: 'handler',
        memorySize: 256,
        timeout: cdk.Duration.seconds(10),
        environment: {
          FRIEND_REALTIME_GRAPHQL_URL: friendRealtimeApi.graphqlUrl,
        },
      },
    );
    publishFriendRealtimeEventFn.addEventSource(
      new lambdaEventSources.DynamoEventSource(friendRequestRealtimeEventsTable, {
        startingPosition: lambda.StartingPosition.LATEST,
        batchSize: 10,
        retryAttempts: 2,
      }),
    );
    friendRealtimeApi.grantMutation(publishFriendRealtimeEventFn);


    const publishChatRealtimeEventFn = new nodejs.NodejsFunction(
      this,
      'PublishChatRealtimeEventFunction',
      {
        functionName: resourceName(stage, 'publish-chat-realtime-event'),
        runtime: lambda.Runtime.NODEJS_20_X,
        entry: '../../services/api/src/handlers/publish-chat-realtime-event.ts',
        handler: 'handler',
        memorySize: 256,
        timeout: cdk.Duration.seconds(10),
        environment: {
          FRIEND_REALTIME_GRAPHQL_URL: friendRealtimeApi.graphqlUrl,
        },
      },
    );
    publishChatRealtimeEventFn.addEventSource(
      new lambdaEventSources.DynamoEventSource(chatRealtimeEventsTable, {
        startingPosition: lambda.StartingPosition.LATEST,
        batchSize: 10,
        retryAttempts: 2,
      }),
    );
    friendRealtimeApi.grantMutation(publishChatRealtimeEventFn);

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
        'gatewayresponse.header.Access-Control-Allow-Headers':
          "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        'gatewayresponse.header.Access-Control-Allow-Methods': "'GET,POST,PUT,DELETE,OPTIONS'",
      },
    });

    api.addGatewayResponse('Default5XX', {
      type: apigateway.ResponseType.DEFAULT_5XX,
      responseHeaders: {
        'gatewayresponse.header.Access-Control-Allow-Origin': "'*'",
        'gatewayresponse.header.Access-Control-Allow-Headers':
          "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
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
    searchResource.addMethod('POST', new apigateway.LambdaIntegration(searchFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── /profile (protected) ────────────────────────────────────
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

    const updateProfileFn = new nodejs.NodejsFunction(this, 'UpdateProfileFunction', {
      functionName: resourceName(stage, 'update-profile'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/update-profile.ts',
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
        COGNITO_USER_POOL_ID: userPool.userPoolId,
      },
      bundling: {
        nodeModules: ['pg'],
      },
    });
    dbCluster.secret!.grantRead(updateProfileFn);
    updateProfileFn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['cognito-idp:AdminUpdateUserAttributes'],
        resources: [userPool.userPoolArn],
      }),
    );

    const checkUsernameAvailabilityFn = new nodejs.NodejsFunction(
      this,
      'CheckUsernameAvailabilityFunction',
      {
        functionName: resourceName(stage, 'check-username-availability'),
        runtime: lambda.Runtime.NODEJS_20_X,
        entry: '../../services/api/src/handlers/check-username-availability.ts',
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
        },
        bundling: {
          nodeModules: ['pg'],
        },
      },
    );
    dbCluster.secret!.grantRead(checkUsernameAvailabilityFn);

    const profileResource = api.root.addResource('profile');
    profileResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'PATCH', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    profileResource.addMethod('GET', new apigateway.LambdaIntegration(profileFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });
    profileResource.addMethod('PATCH', new apigateway.LambdaIntegration(updateProfileFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });
    const usernameAvailabilityResource = profileResource.addResource('username-availability');
    usernameAvailabilityResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    usernameAvailabilityResource.addMethod(
      'GET',
      new apigateway.LambdaIntegration(checkUsernameAvailabilityFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const billingLambdaProps = {
      runtime: lambda.Runtime.NODEJS_20_X,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: billingApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
        USER_PROFILES_TABLE: userProfilesTable.tableName,
        REVENUECAT_MODE: process.env.REVENUECAT_MODE || 'test',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    };

    const syncRevenueCatCustomerFn = new nodejs.NodejsFunction(
      this,
      'SyncRevenueCatCustomerFunction',
      {
        ...billingLambdaProps,
        functionName: resourceName(stage, 'sync-revenuecat-customer'),
        entry: '../../services/api/src/handlers/sync-revenuecat-customer.ts',
        handler: 'handler',
      },
    );

    const revenueCatWebhookFn = new nodejs.NodejsFunction(this, 'RevenueCatWebhookFunction', {
      ...billingLambdaProps,
      functionName: resourceName(stage, 'revenuecat-webhook'),
      entry: '../../services/api/src/handlers/revenuecat-webhook.ts',
      handler: 'handler',
      environment: {
        ...billingLambdaProps.environment,
        REVENUECAT_WEBHOOK_SECRET: process.env.REVENUECAT_WEBHOOK_SECRET || '',
      },
    });

    const billingResource = api.root.addResource('billing');
    const billingRevenueCatResource = billingResource.addResource('revenuecat');
    billingRevenueCatResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization', 'X-RevenueCat-Signature'],
    });

    const billingRevenueCatSyncResource = billingRevenueCatResource.addResource('sync');
    billingRevenueCatSyncResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    billingRevenueCatSyncResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(syncRevenueCatCustomerFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const billingRevenueCatWebhookResource = billingRevenueCatResource.addResource('webhook');
    billingRevenueCatWebhookResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization', 'X-RevenueCat-Signature'],
    });
    billingRevenueCatWebhookResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(revenueCatWebhookFn),
    );

    const mediaResource = api.root.addResource('media');
    const mediaUploadsResource = mediaResource.addResource('uploads');
    mediaUploadsResource.addMethod('POST', new apigateway.LambdaIntegration(createMediaUploadFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const mediaAvatarResource = mediaResource.addResource('avatar');
    mediaAvatarResource.addMethod('POST', new apigateway.LambdaIntegration(createAvatarUploadFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const mediaItemResource = mediaResource.addResource('{mediaId}');
    mediaItemResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    mediaItemResource.addMethod('GET', new apigateway.LambdaIntegration(getMediaFn));

    // === /friends API Routes ===
    const friendsResource = api.root.addResource('friends');
    friendsResource.addMethod('GET', new apigateway.LambdaIntegration(getFriendsFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const requestsResource = friendsResource.addResource('requests');
    requestsResource.addMethod('GET', new apigateway.LambdaIntegration(getFriendRequestsFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const sentRequestsResource = requestsResource.addResource('sent');
    sentRequestsResource.addMethod(
      'GET',
      new apigateway.LambdaIntegration(getSentFriendRequestsFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const requestActionResource = friendsResource.addResource('request');
    requestActionResource.addMethod('POST', new apigateway.LambdaIntegration(sendFriendRequestFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });
    requestActionResource.addMethod(
      'DELETE',
      new apigateway.LambdaIntegration(cancelFriendRequestFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const acceptActionResource = friendsResource.addResource('accept');
    acceptActionResource.addMethod('POST', new apigateway.LambdaIntegration(acceptFriendFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const declineActionResource = friendsResource.addResource('decline');
    declineActionResource.addMethod('POST', new apigateway.LambdaIntegration(declineFriendFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });
    const searchFriendsResource = friendsResource.addResource('search');
    searchFriendsResource.addMethod('GET', new apigateway.LambdaIntegration(searchFriendsFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const unfriendActionResource = friendsResource.addResource('unfriend');
    unfriendActionResource.addMethod('POST', new apigateway.LambdaIntegration(unfriendFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const hideFriendActionResource = friendsResource.addResource('hide');
    hideFriendActionResource.addMethod('POST', new apigateway.LambdaIntegration(hideFriendFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const blockFriendActionResource = friendsResource.addResource('block');
    blockFriendActionResource.addMethod('POST', new apigateway.LambdaIntegration(blockFriendFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // === /conversations API Routes ===
    // ─── Chat APIs moved to ChatApiStack ─────────────────────────────
    
    // ─── POST /place-candidates (protected) ─────────────────────
    const createPlaceCandidateFn = new nodejs.NodejsFunction(this, 'CreatePlaceCandidateFunction', {
      functionName: resourceName(stage, 'create-place-candidate'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-place-candidate.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(15),
      role: placeCandidateApiLambdaRole,
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

    // ─── GET /place-candidates (protected) ──────────────────────
    const getPlaceCandidatesFn = new nodejs.NodejsFunction(this, 'GetPlaceCandidatesFunction', {
      functionName: resourceName(stage, 'get-place-candidates'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-place-candidates.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placeCandidateApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const updatePlaceCandidateFn = new nodejs.NodejsFunction(this, 'UpdatePlaceCandidateFunction', {
      functionName: resourceName(stage, 'update-place-candidate'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/update-place-candidate.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placeCandidateApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const placeCandidatesResource = api.root.addResource('place-candidates');
    placeCandidatesResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'POST', 'PATCH', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    placeCandidatesResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(createPlaceCandidateFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );
    placeCandidatesResource.addMethod(
      'GET',
      new apigateway.LambdaIntegration(getPlaceCandidatesFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const placeCandidateResource = placeCandidatesResource.addResource('{id}');
    placeCandidateResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['PATCH', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    placeCandidateResource.addMethod(
      'PATCH',
      new apigateway.LambdaIntegration(updatePlaceCandidateFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    // ─── POST /place-candidates/quick (protected) ────────────────
    const createQuickPlaceFn = new nodejs.NodejsFunction(this, 'CreateQuickPlaceFunction', {
      functionName: resourceName(stage, 'create-quick-place'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-quick-place.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placeCandidateApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        USER_PROFILES_TABLE: userProfilesTable.tableName,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const quickPlaceResource = placeCandidatesResource.addResource('quick');
    quickPlaceResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    quickPlaceResource.addMethod('POST', new apigateway.LambdaIntegration(createQuickPlaceFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── Comments API (protected) ───────────────────────────────
    const createCommentFn = new nodejs.NodejsFunction(this, 'CreateCommentFunction', {
      functionName: resourceName(stage, 'create-comment'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-comment.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const getCommentsFn = new nodejs.NodejsFunction(this, 'GetCommentsFunction', {
      functionName: resourceName(stage, 'get-comments'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-comments.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const getCommentRepliesFn = new nodejs.NodejsFunction(this, 'GetCommentRepliesFunction', {
      functionName: resourceName(stage, 'get-comment-replies'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-comment-replies.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const deleteCommentFn = new nodejs.NodejsFunction(this, 'DeleteCommentFunction', {
      functionName: resourceName(stage, 'delete-comment'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/delete-comment.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const commentsResource = api.root.addResource('comments');
    commentsResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    commentsResource.addMethod('POST', new apigateway.LambdaIntegration(createCommentFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });
    commentsResource.addMethod('GET', new apigateway.LambdaIntegration(getCommentsFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const commentResource = commentsResource.addResource('{commentId}');
    commentResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['DELETE', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    commentResource.addMethod('DELETE', new apigateway.LambdaIntegration(deleteCommentFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const commentRepliesResource = commentResource.addResource('replies');
    commentRepliesResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    commentRepliesResource.addMethod(
      'GET',
      new apigateway.LambdaIntegration(getCommentRepliesFn),
      {
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
      role: placesApiLambdaRole,
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

    const mapResource = api.root.addResource('map');
    const mapFeedResource = mapResource.addResource('feed');
    mapFeedResource.addMethod('GET', new apigateway.LambdaIntegration(getMapFeedFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /map/heatmap (protected) ────────────────────────────
    const getHeatmapFn = new nodejs.NodejsFunction(this, 'GetHeatmapFunction', {
      functionName: resourceName(stage, 'get-heatmap'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-heatmap.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const mapHeatmapResource = mapResource.addResource('heatmap');
    mapHeatmapResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    mapHeatmapResource.addMethod('GET', new apigateway.LambdaIntegration(getHeatmapFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /discovery/feed (protected) ─────────────────────────
    const getDiscoveryFeedFn = new nodejs.NodejsFunction(this, 'GetDiscoveryFeedFunction', {
      functionName: resourceName(stage, 'get-discovery-feed'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-discovery-feed.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(15),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const discoveryResource = api.root.addResource('discovery');
    const discoveryFeedResource = discoveryResource.addResource('feed');
    discoveryFeedResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    discoveryFeedResource.addMethod('GET', new apigateway.LambdaIntegration(getDiscoveryFeedFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /discovery/search (protected) ───────────────────────
    const discoverySearchFn = new nodejs.NodejsFunction(this, 'DiscoverySearchFunction', {
      functionName: resourceName(stage, 'discovery-search'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/discovery-search.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(15),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const discoverySearchResource = discoveryResource.addResource('search');
    discoverySearchResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    discoverySearchResource.addMethod('GET', new apigateway.LambdaIntegration(discoverySearchFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /feed/checkins (protected) ─────────────────────────
    const getCheckinFeedFn = new nodejs.NodejsFunction(this, 'GetCheckinFeedFunction', {
      functionName: resourceName(stage, 'get-checkin-feed'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-checkin-feed.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
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

    const globalFeedResource = api.root.getResource('feed') || api.root.addResource('feed');
    const checkinFeedResource = globalFeedResource.addResource('checkins');
    checkinFeedResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    checkinFeedResource.addMethod('GET', new apigateway.LambdaIntegration(getCheckinFeedFn), {
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
      role: placesApiLambdaRole,
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

    const placesResource = api.root.getResource('places') || api.root.addResource('places');
    const nearbyPlacesResource =
      placesResource.getResource('nearby') || placesResource.addResource('nearby');
    nearbyPlacesResource.addMethod('GET', new apigateway.LambdaIntegration(getNearbyPlacesFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /places/{id} (protected, BFF) ──────────────────────
    const getPlaceDetailFn = new nodejs.NodejsFunction(this, 'GetPlaceDetailFunction', {
      functionName: resourceName(stage, 'get-place-detail'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-place-detail.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(15),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const placeIdResource = placesResource.addResource('{id}');
    placeIdResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    placeIdResource.addMethod('GET', new apigateway.LambdaIntegration(getPlaceDetailFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /places/{id}/reviews (protected) ────────────────────
    const getPlaceReviewsFn = new nodejs.NodejsFunction(this, 'GetPlaceReviewsFunction', {
      functionName: resourceName(stage, 'get-place-reviews'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-place-reviews.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const placeReviewsResource = placeIdResource.addResource('reviews');
    placeReviewsResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    placeReviewsResource.addMethod('GET', new apigateway.LambdaIntegration(getPlaceReviewsFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── POST /reviews (protected) ──────────────────────────────
    const createReviewFn = new nodejs.NodejsFunction(this, 'CreateReviewFunction', {
      functionName: resourceName(stage, 'create-review'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-review.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const reviewsResource = api.root.addResource('reviews');
    reviewsResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    reviewsResource.addMethod('POST', new apigateway.LambdaIntegration(createReviewFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── POST /check-ins (protected) ────────────────────────────
    const createCheckinFn = new nodejs.NodejsFunction(this, 'CreateCheckinFunction', {
      functionName: resourceName(stage, 'create-checkin'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/create-checkin.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbCluster.secret!.secretArn,
        DB_NAME: 'fidee',
      },
      bundling: { nodeModules: ['pg'] },
    });

    const checkinsResource = api.root.addResource('check-ins');
    checkinsResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    checkinsResource.addMethod('POST', new apigateway.LambdaIntegration(createCheckinFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── GET /journey/checkins & /journey/reviews (VPC, connects to Aurora) ────────────
    const getJourneyCheckinsFn = new nodejs.NodejsFunction(this, 'GetJourneyCheckinsFunction', {
      functionName: resourceName(stage, 'get-journey-checkins'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-journey-checkins.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
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

    const getJourneyReviewsFn = new nodejs.NodejsFunction(this, 'GetJourneyReviewsFunction', {
      functionName: resourceName(stage, 'get-journey-reviews'),
      runtime: lambda.Runtime.NODEJS_20_X,
      entry: '../../services/api/src/handlers/get-journey-reviews.ts',
      handler: 'handler',
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      role: placesApiLambdaRole,
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

    const journeyResource = api.root.addResource('journey');

    const journeyCheckinsResource = journeyResource.addResource('checkins');
    journeyCheckinsResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    journeyCheckinsResource.addMethod(
      'GET',
      new apigateway.LambdaIntegration(getJourneyCheckinsFn),
      {
        authorizer: cognitoAuthorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const journeyReviewsResource = journeyResource.addResource('reviews');
    journeyReviewsResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    journeyReviewsResource.addMethod('GET', new apigateway.LambdaIntegration(getJourneyReviewsFn), {
      authorizer: cognitoAuthorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // ─── Chat APIs (Nested Stack) ──────────────────────────────────
    const chatApiStack = new ChatApiStack(this, 'ChatApiNestedStack', {
      api,
      authorizer: cognitoAuthorizer,
      vpc,
      lambdaSecurityGroup,
      dbSecret: dbCluster.secret!,
      chatRealtimeEventsTable,
      chatPresenceTable,
      stage,
    });

    // ─── Admin APIs (Nested Stack) ──────────────────────
    const adminApiStack = new AdminApiStack(this, 'AdminApiNestedStack', {
      api,
      authorizer: cognitoAuthorizer,
      vpc,
      lambdaSecurityGroup,
      dbSecret: dbCluster.secret!,
      userProfilesTable,
      stage,
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
