import { describe, it, expect } from 'vitest';
import * as cdk from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import {
  assertFideeStage,
  CLOUDFRONT_WAF_REGION,
  MAIN_REGION,
  FideeMediaWafStack,
  FideeStack,
} from '../lib/fidee-stack';

const createDevTemplates = () => {
  const app = new cdk.App();
  const mediaWafStack = new FideeMediaWafStack(app, 'TestMediaWafStack', {
    stage: 'dev',
    env: { account: '123456789012', region: CLOUDFRONT_WAF_REGION },
  });
  const stack = new FideeStack(app, 'TestStack', {
    stage: 'dev',
    env: { account: '123456789012', region: MAIN_REGION },
    mediaWebAclArn: mediaWafStack.webAclArn,
  });

  return {
    mediaWafStack,
    mediaTemplate: Template.fromStack(mediaWafStack),
    stack,
    template: Template.fromStack(stack),
  };
};

type CfnValue = string | Record<string, unknown>;
type CfnPolicyStatement = {
  Action?: CfnValue | CfnValue[];
  Resource?: CfnValue | CfnValue[];
};
type CfnInlinePolicy = {
  PolicyDocument?: {
    Statement?: CfnPolicyStatement | CfnPolicyStatement[];
  };
};
type CfnResource = {
  Properties?: {
    PolicyDocument?: {
      Statement?: CfnPolicyStatement | CfnPolicyStatement[];
    };
    Policies?: CfnInlinePolicy[];
  };
};
type CfnTemplateResource = {
  Type?: string;
  Properties?: {
    FunctionName?: string;
    Role?: unknown;
  };
};
type CfnPolicyStatementWithOwner = {
  logicalId: string;
  statement: CfnPolicyStatement;
};

const asArray = <T>(value: T | T[] | undefined): T[] => {
  if (value === undefined) {
    return [];
  }

  return Array.isArray(value) ? value : [value];
};

const policyStatementsFromResources = (
  resources: Record<string, unknown>,
): CfnPolicyStatementWithOwner[] =>
  Object.entries(resources).flatMap(([logicalId, resource]) => {
    const properties = (resource as CfnResource).Properties;
    const resourcePolicyStatements = asArray(properties?.PolicyDocument?.Statement);
    const roleInlinePolicyStatements = asArray(properties?.Policies).flatMap((policy) =>
      asArray(policy.PolicyDocument?.Statement),
    );

    return [...resourcePolicyStatements, ...roleInlinePolicyStatements].map((statement) => ({
      logicalId,
      statement,
    }));
  });

const stackResources = (template: Template) =>
  ((template.toJSON() as { Resources?: Record<string, unknown> }).Resources ?? {});

const resourceCountsByType = (resources: Record<string, unknown>) =>
  Object.values(resources).reduce<Record<string, number>>((counts, resource) => {
    const type = (resource as CfnTemplateResource).Type ?? 'Unknown';
    counts[type] = (counts[type] ?? 0) + 1;
    return counts;
  }, {});

const roleRefForFunctionName = (resources: Record<string, unknown>, functionName: string) => {
  const resource = Object.values(resources).find((item) => {
    const lambdaResource = item as CfnTemplateResource;
    return (
      lambdaResource.Type === 'AWS::Lambda::Function' &&
      lambdaResource.Properties?.FunctionName === functionName
    );
  }) as CfnTemplateResource | undefined;

  expect(resource).toBeDefined();
  return resource?.Properties?.Role;
};

const stringValues = (value: CfnValue | CfnValue[] | undefined): string[] =>
  asArray(value).filter((item): item is string => typeof item === 'string');

const sorted = (values: string[]) => [...values].sort();

const hasOnlyActions = (statement: CfnPolicyStatement, expected: string[]) => {
  const actions = sorted(stringValues(statement.Action));
  const expectedActions = sorted(expected);
  return (
    actions.length === expectedActions.length &&
    expectedActions.every((action, index) => action === actions[index])
  );
};

const hasWildcardResource = (statement: CfnPolicyStatement) =>
  stringValues(statement.Resource).includes('*');

const isAllowedWildcardStatement = ({
  logicalId,
  statement,
}: CfnPolicyStatementWithOwner) => {
  if (!hasWildcardResource(statement)) return true;

  // SNS Publish to phone numbers cannot be scoped to ARNs.
  if (hasOnlyActions(statement, ['sns:Publish'])) return true;

  // CDK's LogRetention provider manages log groups generated at deploy time.
  if (
    logicalId.startsWith('LogRetention') &&
    hasOnlyActions(statement, ['logs:DeleteRetentionPolicy', 'logs:PutRetentionPolicy'])
  ) {
    return true;
  }

  // Session Manager policies for the EC2 bastion require wildcard resources.
  if (
    logicalId.startsWith('BastionHostInstanceRoleDefaultPolicy') &&
    hasOnlyActions(statement, ['ec2messages:*', 'ssm:UpdateInstanceInformation', 'ssmmessages:*'])
  ) {
    return true;
  }

  // DynamoDB ListStreams is not resource-scoped; stream reads below remain scoped.
  if (
    (logicalId.startsWith('PublishFriendRealtimeEventFunctionServiceRoleDefaultPolicy') ||
      logicalId.startsWith('PublishChatRealtimeEventFunctionServiceRoleDefaultPolicy')) &&
    hasOnlyActions(statement, ['dynamodb:ListStreams'])
  ) {
    return true;
  }

  return false;
};

describe('Fidee stage validation', () => {
  it('allows dev and prod only', () => {
    expect(assertFideeStage('dev')).toBe('dev');
    expect(assertFideeStage('prod')).toBe('prod');
    expect(() => assertFideeStage('staging')).toThrow('Unsupported stage');
  });
});

describe('FideeStack', () => {
  const { mediaWafStack, mediaTemplate, stack, template } = createDevTemplates();

  it('uses ap-southeast-1 for the main stack and us-east-1 for CloudFront WAF', () => {
    expect(stack.region).toBe(MAIN_REGION);
    expect(mediaWafStack.region).toBe(CLOUDFRONT_WAF_REGION);
  });

  it('creates core resources', () => {
    template.resourceCountIs('AWS::Cognito::UserPool', 1);
    template.resourceCountIs('AWS::DynamoDB::Table', 5);
    template.resourceCountIs('AWS::S3::Bucket', 1);
    template.resourceCountIs('AWS::CloudFront::Distribution', 1);
    template.resourceCountIs('AWS::ApiGateway::RestApi', 1);
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-search',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-create-media-upload',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-handle-media-uploaded',
    });
    mediaTemplate.resourceCountIs('AWS::WAFv2::WebACL', 1);
    template.resourceCountIs('AWS::WAFv2::WebACL', 1);
  });

  it('keeps the main stack below the CloudFormation resource limit with deploy headroom', () => {
    const resources = stackResources(template);
    const counts = resourceCountsByType(resources);

    expect(Object.keys(resources).length).toBeLessThanOrEqual(470);
    expect(counts['AWS::IAM::Role'] ?? 0).toBeLessThanOrEqual(40);
    expect(counts['AWS::IAM::Policy'] ?? 0).toBeLessThanOrEqual(35);
  });

  it('shares execution roles across high-volume API Lambda groups', () => {
    const resources = stackResources(template);

    expect(roleRefForFunctionName(resources, 'fidee-dev-get-friends')).toEqual(
      roleRefForFunctionName(resources, 'fidee-dev-send-friend-request'),
    );
    expect(roleRefForFunctionName(resources, 'fidee-dev-list-conversations')).toEqual(
      roleRefForFunctionName(resources, 'fidee-dev-send-chat-message'),
    );
    expect(roleRefForFunctionName(resources, 'fidee-dev-sync-revenuecat-customer')).toEqual(
      roleRefForFunctionName(resources, 'fidee-dev-revenuecat-webhook'),
    );
    expect(roleRefForFunctionName(resources, 'fidee-dev-create-place-candidate')).toEqual(
      roleRefForFunctionName(resources, 'fidee-dev-create-quick-place'),
    );
    expect(roleRefForFunctionName(resources, 'fidee-dev-get-map-feed')).toEqual(
      roleRefForFunctionName(resources, 'fidee-dev-create-checkin'),
    );
    expect(roleRefForFunctionName(resources, 'fidee-dev-get-pending-places')).toEqual(
      roleRefForFunctionName(resources, 'fidee-dev-request-info-candidate'),
    );
  });

  it('creates Cognito groups for RBAC', () => {
    template.resourceCountIs('AWS::Cognito::UserPoolGroup', 3);
    template.hasResourceProperties('AWS::Cognito::UserPoolGroup', {
      GroupName: 'Users',
    });
    template.hasResourceProperties('AWS::Cognito::UserPoolGroup', {
      GroupName: 'Moderators',
    });
    template.hasResourceProperties('AWS::Cognito::UserPoolGroup', {
      GroupName: 'Admins',
    });
  });

  // The app's current auth flow is email-first. The pre-sign-up trigger can auto-verify
  // a phone_number attribute if Cognito receives one, but phone is not a sign-in alias.
  it('configures Cognito with email sign-in', () => {
    template.hasResourceProperties('AWS::Cognito::UserPool', {
      UsernameAttributes: ['email'],
      AutoVerifiedAttributes: ['email'],
    });
  });

  it('creates auth trigger Lambda functions', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-define-auth',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-create-auth',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-verify-auth',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-pre-sign-up',
    });
  });

  it('creates a protected GET /profile endpoint', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-get-profile',
    });
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      HttpMethod: 'GET',
      AuthorizationType: 'COGNITO_USER_POOLS',
    });
  });

  it('creates a protected PATCH /profile endpoint for unique username updates', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-update-profile',
    });
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      HttpMethod: 'PATCH',
      AuthorizationType: 'COGNITO_USER_POOLS',
    });
    template.hasResourceProperties('AWS::IAM::Policy', {
      PolicyDocument: {
        Statement: Match.arrayWith([
          Match.objectLike({
            Action: 'cognito-idp:AdminUpdateUserAttributes',
            Effect: 'Allow',
          }),
        ]),
      },
    });
  });

  it('creates a protected POST /media/uploads endpoint', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-create-media-upload',
    });
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      HttpMethod: 'POST',
      AuthorizationType: 'COGNITO_USER_POOLS',
    });
  });

  it('creates a public GET /media/{mediaId} redirect endpoint', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-get-media',
    });
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      HttpMethod: 'GET',
    });
  });

  it('names dev resources with fidee-dev prefix', () => {
    template.hasResourceProperties('AWS::Cognito::UserPool', {
      UserPoolName: 'fidee-dev-users',
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'fidee-dev-places',
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'fidee-dev-user-profiles',
    });
    template.hasResourceProperties('AWS::ApiGateway::RestApi', {
      Name: 'fidee-dev-api',
    });
    mediaTemplate.hasResourceProperties('AWS::WAFv2::WebACL', {
      Name: 'fidee-dev-media-waf',
    });
  });

  it('enables DynamoDB TTL', () => {
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TimeToLiveSpecification: {
        AttributeName: 'expiresAt',
        Enabled: true,
      },
    });
  });

  it('creates AppSync friend request realtime infrastructure', () => {
    template.resourceCountIs('AWS::AppSync::GraphQLApi', 1);
    template.resourceCountIs('AWS::AppSync::GraphQLSchema', 1);
    template.hasResourceProperties('AWS::AppSync::GraphQLApi', {
      Name: 'fidee-dev-friend-realtime',
      AuthenticationType: 'AMAZON_COGNITO_USER_POOLS',
    });
    template.hasResourceProperties('AWS::AppSync::GraphQLApi', {
      AdditionalAuthenticationProviders: Match.arrayWith([
        Match.objectLike({ AuthenticationType: 'AWS_IAM' }),
      ]),
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'fidee-dev-friend-request-realtime-events',
      StreamSpecification: { StreamViewType: 'NEW_IMAGE' },
      TimeToLiveSpecification: {
        AttributeName: 'expiresAt',
        Enabled: true,
      },
    });
    template.hasResourceProperties('AWS::AppSync::Resolver', {
      TypeName: 'Mutation',
      FieldName: 'publishFriendRequestReceived',
    });
    template.hasResourceProperties('AWS::AppSync::Resolver', {
    TypeName: 'Mutation',
    FieldName: 'publishFriendRequestCanceled',
    });
    template.hasResourceProperties('AWS::AppSync::Resolver', {
    TypeName: 'Mutation',
    FieldName: 'publishFriendRealtimeEvent',
      });
      template.hasResourceProperties('AWS::AppSync::Resolver', {
        TypeName: 'Subscription',
        FieldName: 'onFriendRealtimeEvent',
        RequestMappingTemplate: Match.stringLikeRegexp('ctx.identity.sub'),
        ResponseMappingTemplate: '$util.toJson(null)',
      });
      template.hasResourceProperties('AWS::AppSync::Resolver', {
        TypeName: 'Subscription',
        FieldName: 'onFriendRequestReceived',
      RequestMappingTemplate: Match.stringLikeRegexp('payload":null'),
      ResponseMappingTemplate: '$util.toJson(null)',
    });
    template.hasResourceProperties('AWS::AppSync::Resolver', {
      TypeName: 'Subscription',
      FieldName: 'onFriendRequestCanceled',
      RequestMappingTemplate: Match.stringLikeRegexp('payload":null'),
      ResponseMappingTemplate: '$util.toJson(null)',
    });
  });

  it('creates sent friend request and cancel endpoints', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-get-sent-friend-requests',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'fidee-dev-cancel-friend-request',
    });
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      HttpMethod: 'DELETE',
      AuthorizationType: 'COGNITO_USER_POOLS',
    });
  });

  it('grants friendship mutation Lambdas access to the realtime event table', () => {
  for (const functionName of [
  'fidee-dev-send-friend-request',
        'fidee-dev-cancel-friend-request',
        'fidee-dev-accept-friend',
        'fidee-dev-decline-friend',
        'fidee-dev-unfriend',
        'fidee-dev-hide-friend',
        'fidee-dev-block-friend',
      ]) {
        template.hasResourceProperties('AWS::Lambda::Function', {
          FunctionName: functionName,
          Environment: {
            Variables: Match.objectLike({
              FRIEND_REQUEST_REALTIME_EVENTS_TABLE: Match.anyValue(),
            }),
          },
        });
      }
    });

    it('wires the friend realtime publisher Lambda to the event stream', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        FunctionName: 'fidee-dev-publish-friend-realtime-event',
      Environment: {
        Variables: Match.objectLike({
          FRIEND_REALTIME_GRAPHQL_URL: Match.anyValue(),
        }),
      },
    });
    template.hasResourceProperties('AWS::Lambda::EventSourceMapping', {
      BatchSize: 10,
      StartingPosition: 'LATEST',
    });
    template.hasResourceProperties('AWS::IAM::Policy', {
      PolicyDocument: {
        Statement: Match.arrayWith([
          Match.objectLike({
            Action: 'appsync:GraphQL',
            Effect: 'Allow',
          }),
        ]),
      },
    });
  });

  it('keeps the media bucket private and encrypted', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      BucketEncryption: {
        ServerSideEncryptionConfiguration: [
          {
            ServerSideEncryptionByDefault: {
              SSEAlgorithm: 'AES256',
            },
          },
        ],
      },
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true,
      },
    });
  });

  it('uses CloudFront OAC and attaches the media WAF', () => {
    template.resourceCountIs('AWS::CloudFront::OriginAccessControl', 1);
    template.hasResourceProperties('AWS::CloudFront::Distribution', {
      DistributionConfig: Match.objectLike({
        WebACLId: Match.anyValue(),
      }),
    });
  });

  it('creates regional API WAF and associates it with the API Gateway stage', () => {
    template.hasResourceProperties('AWS::WAFv2::WebACL', {
      Name: 'fidee-dev-api-waf',
      Scope: 'REGIONAL',
    });
    template.hasResourceProperties('AWS::WAFv2::WebACLAssociation', {
      WebACLArn: Match.anyValue(),
      ResourceArn: Match.anyValue(),
    });
  });

  it('enables S3 EventBridge notifications for media uploads', () => {
    template.hasResourceProperties('Custom::S3BucketNotifications', {
      NotificationConfiguration: {
        EventBridgeConfiguration: {},
      },
    });
  });

  it('routes media upload object-created events through EventBridge to SQS', () => {
    template.resourceCountIs('AWS::SQS::Queue', 2);
    template.hasResourceProperties('AWS::SQS::Queue', {
      QueueName: 'fidee-dev-media-upload-events',
      RedrivePolicy: {
        deadLetterTargetArn: Match.anyValue(),
        maxReceiveCount: 3,
      },
    });
    template.hasResourceProperties('AWS::SQS::Queue', {
      QueueName: 'fidee-dev-media-upload-events-dlq',
    });
    template.hasResourceProperties('AWS::Events::Rule', {
      Name: 'fidee-dev-media-upload-object-created',
      EventPattern: Match.objectLike({
        source: ['aws.s3'],
        'detail-type': ['Object Created'],
        detail: Match.objectLike({
          object: {
            key: [{ prefix: 'uploads/' }],
          },
        }),
      }),
      Targets: Match.arrayWith([
        Match.objectLike({
          Arn: Match.anyValue(),
        }),
      ]),
    });
  });

  it('configures the media upload worker to consume SQS events', () => {
    template.hasResourceProperties('AWS::Lambda::EventSourceMapping', {
      BatchSize: 10,
      EventSourceArn: Match.anyValue(),
    });
  });

  it('creates CloudFront-scoped media WAF', () => {
    mediaTemplate.hasResourceProperties('AWS::WAFv2::WebACL', {
      Name: 'fidee-dev-media-waf',
      Scope: 'CLOUDFRONT',
    });
  });

  it('adds non-production cleanup tags', () => {
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      Tags: Match.arrayWith([{ Key: 'Environment', Value: 'dev' }]),
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      Tags: Match.arrayWith([{ Key: 'AutoCleanup', Value: 'true' }]),
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      Tags: Match.arrayWith([{ Key: 'CostCenter', Value: 'fidee' }]),
    });
  });

  it('does not write unexpected wildcard IAM actions or resources', () => {
    const statements = [
      ...policyStatementsFromResources(template.findResources('AWS::IAM::Policy')),
      ...policyStatementsFromResources(template.findResources('AWS::IAM::Role')),
    ];

    const wildcardActions = statements.filter(({ statement }) =>
      stringValues(statement.Action).includes('*'),
    );
    const unexpectedWildcardResources = statements.filter(
      (entry) => hasWildcardResource(entry.statement) && !isAllowedWildcardStatement(entry),
    );

    expect(wildcardActions).toEqual([]);
    expect(unexpectedWildcardResources).toEqual([]);
  });
});
