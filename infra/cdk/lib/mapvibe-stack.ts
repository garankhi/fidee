import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as wafv2 from 'aws-cdk-lib/aws-wafv2';
import { Construct } from 'constructs';

export const MAIN_REGION = 'ap-southeast-1';
export const CLOUDFRONT_WAF_REGION = 'us-east-1';
export const SUPPORTED_STAGES = ['dev', 'prod'] as const;

export type MapVibeStage = (typeof SUPPORTED_STAGES)[number];

export function assertMapVibeStage(stage: string): MapVibeStage {
  if (SUPPORTED_STAGES.includes(stage as MapVibeStage)) {
    return stage as MapVibeStage;
  }

  throw new Error(`Unsupported stage "${stage}". Use one of: ${SUPPORTED_STAGES.join(', ')}`);
}

interface StageProps extends cdk.StackProps {
  stage: MapVibeStage;
}

export type MapVibeMediaWafStackProps = StageProps;

export interface MapVibeStackProps extends StageProps {
  mediaWebAclArn: string;
}

const isProd = (stage: MapVibeStage) => stage === 'prod';
const resourceName = (stage: MapVibeStage, resource: string) => `mapvibe-${stage}-${resource}`;

function applyStageTags(scope: Construct, stage: MapVibeStage) {
  cdk.Tags.of(scope).add('Project', 'mapvibe');
  cdk.Tags.of(scope).add('Environment', stage);
  cdk.Tags.of(scope).add('CostCenter', 'mapvibe');
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

function rateLimitRule(stage: MapVibeStage): wafv2.CfnWebACL.RuleProperty {
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

function webAclRules(stage: MapVibeStage): wafv2.CfnWebACL.RuleProperty[] {
  return [
    managedRule('AwsCommonRules', 10, 'AWSManagedRulesCommonRuleSet'),
    managedRule('AwsKnownBadInputs', 20, 'AWSManagedRulesKnownBadInputsRuleSet'),
    managedRule('AwsIpReputation', 30, 'AWSManagedRulesAmazonIpReputationList'),
    rateLimitRule(stage),
  ];
}

export class MapVibeMediaWafStack extends cdk.Stack {
  public readonly webAclArn: string;

  constructor(scope: Construct, id: string, props: MapVibeMediaWafStackProps) {
    super(scope, id, props);

    const stage = assertMapVibeStage(props.stage);
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

export class MapVibeStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: MapVibeStackProps) {
    super(scope, id, props);

    const stage = assertMapVibeStage(props.stage);
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
        SES_SENDER_EMAIL: `noreply@mapvibe.com`,
      },
    });

    // Grant SNS publish for SMS (resource must be * for phone number targets)
    createAuthChallengeFn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['sns:Publish'],
        resources: ['*'],
      }),
    );
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
      signInAliases: { email: true, phone: true },
      autoVerify: { email: true, phone: true },
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
      authFlows: { userSrp: true, custom: true },
    });

    const placesTable = new dynamodb.Table(this, 'PlacesTable', {
      tableName: resourceName(stage, 'places'),
      partitionKey: { name: 'PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'SK', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'expiresAt',
      removalPolicy,
    });

    placesTable.addGlobalSecondaryIndex({
      indexName: 'GSI1',
      partitionKey: { name: 'GSI1PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'GSI1SK', type: dynamodb.AttributeType.STRING },
    });

    const mediaBucket = new s3.Bucket(this, 'MediaBucket', {
      bucketName: `${resourceName(stage, 'media')}-${cdk.Aws.ACCOUNT_ID}-${MAIN_REGION}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      removalPolicy,
      autoDeleteObjects: !isProd(stage),
    });

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
    new cdk.CfnOutput(this, 'MediaBucketName', { value: mediaBucket.bucketName });
    new cdk.CfnOutput(this, 'MediaDistributionDomainName', {
      value: mediaDistribution.distributionDomainName,
    });
    new cdk.CfnOutput(this, 'ApiWebAclArn', { value: apiWebAcl.attrArn });
    new cdk.CfnOutput(this, 'MediaWebAclArn', { value: props.mediaWebAclArn });
  }
}
