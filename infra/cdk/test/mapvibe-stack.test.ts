import { describe, it, expect } from 'vitest';
import * as cdk from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import {
  assertMapVibeStage,
  CLOUDFRONT_WAF_REGION,
  MAIN_REGION,
  MapVibeMediaWafStack,
  MapVibeStack,
} from '../lib/mapvibe-stack';

const createDevTemplates = () => {
  const app = new cdk.App();
  const mediaWafStack = new MapVibeMediaWafStack(app, 'TestMediaWafStack', {
    stage: 'dev',
    env: { account: '123456789012', region: CLOUDFRONT_WAF_REGION },
  });
  const stack = new MapVibeStack(app, 'TestStack', {
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

const asArray = <T>(value: T | T[] | undefined): T[] => {
  if (value === undefined) {
    return [];
  }

  return Array.isArray(value) ? value : [value];
};

const policyStatementsFromResources = (resources: Record<string, unknown>): CfnPolicyStatement[] =>
  Object.values(resources).flatMap((resource) => {
    const properties = (resource as CfnResource).Properties;
    const resourcePolicyStatements = asArray(properties?.PolicyDocument?.Statement);
    const roleInlinePolicyStatements = asArray(properties?.Policies).flatMap((policy) =>
      asArray(policy.PolicyDocument?.Statement),
    );

    return [...resourcePolicyStatements, ...roleInlinePolicyStatements];
  });

describe('MapVibe stage validation', () => {
  it('allows dev and prod only', () => {
    expect(assertMapVibeStage('dev')).toBe('dev');
    expect(assertMapVibeStage('prod')).toBe('prod');
    expect(() => assertMapVibeStage('staging')).toThrow('Unsupported stage');
  });
});

describe('MapVibeStack', () => {
  const { mediaWafStack, mediaTemplate, stack, template } = createDevTemplates();

  it('uses ap-southeast-1 for the main stack and us-east-1 for CloudFront WAF', () => {
    expect(stack.region).toBe(MAIN_REGION);
    expect(mediaWafStack.region).toBe(CLOUDFRONT_WAF_REGION);
  });

  it('creates core resources', () => {
    template.resourceCountIs('AWS::Cognito::UserPool', 1);
    template.resourceCountIs('AWS::DynamoDB::Table', 2);
    template.resourceCountIs('AWS::S3::Bucket', 1);
    template.resourceCountIs('AWS::CloudFront::Distribution', 1);
    template.resourceCountIs('AWS::ApiGateway::RestApi', 1);
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-search',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-create-media-upload',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-handle-media-uploaded',
    });
    mediaTemplate.resourceCountIs('AWS::WAFv2::WebACL', 1);
    template.resourceCountIs('AWS::WAFv2::WebACL', 1);
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

  it('configures Cognito with phone and email sign-in', () => {
    template.hasResourceProperties('AWS::Cognito::UserPool', {
      UsernameAttributes: Match.arrayWith(['email', 'phone_number']),
      AutoVerifiedAttributes: Match.arrayWith(['email', 'phone_number']),
    });
  });

  it('creates auth trigger Lambda functions', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-define-auth',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-create-auth',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-verify-auth',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-pre-sign-up',
    });
  });

  it('creates a protected GET /profile endpoint', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-get-profile',
    });
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      HttpMethod: 'GET',
      AuthorizationType: 'COGNITO_USER_POOLS',
    });
  });

  it('creates a protected POST /media/uploads endpoint', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-create-media-upload',
    });
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      HttpMethod: 'POST',
      AuthorizationType: 'COGNITO_USER_POOLS',
    });
  });

  it('names dev resources with mapvibe-dev prefix', () => {
    template.hasResourceProperties('AWS::Cognito::UserPool', {
      UserPoolName: 'mapvibe-dev-users',
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'mapvibe-dev-places',
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'mapvibe-dev-user-profiles',
    });
    template.hasResourceProperties('AWS::ApiGateway::RestApi', {
      Name: 'mapvibe-dev-api',
    });
    mediaTemplate.hasResourceProperties('AWS::WAFv2::WebACL', {
      Name: 'mapvibe-dev-media-waf',
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
      Name: 'mapvibe-dev-api-waf',
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
      QueueName: 'mapvibe-dev-media-upload-events',
      RedrivePolicy: {
        deadLetterTargetArn: Match.anyValue(),
        maxReceiveCount: 3,
      },
    });
    template.hasResourceProperties('AWS::SQS::Queue', {
      QueueName: 'mapvibe-dev-media-upload-events-dlq',
    });
    template.hasResourceProperties('AWS::Events::Rule', {
      Name: 'mapvibe-dev-media-upload-object-created',
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
      Name: 'mapvibe-dev-media-waf',
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
      Tags: Match.arrayWith([{ Key: 'CostCenter', Value: 'mapvibe' }]),
    });
  });

  it('uses retain policies in prod', () => {
    const app = new cdk.App();
    const prodStack = new MapVibeStack(app, 'ProdStack', {
      stage: 'prod',
      env: { account: '123456789012', region: MAIN_REGION },
      mediaWebAclArn:
        'arn:aws:wafv2:us-east-1:123456789012:global/webacl/mapvibe-prod-media-waf/example',
    });
    const prodTemplate = Template.fromStack(prodStack);

    prodTemplate.hasResource('AWS::DynamoDB::Table', {
      DeletionPolicy: 'Retain',
      UpdateReplacePolicy: 'Retain',
    });
    prodTemplate.hasResource('AWS::S3::Bucket', {
      DeletionPolicy: 'Retain',
      UpdateReplacePolicy: 'Retain',
    });
  });

  it('does not write wildcard IAM actions or resources (except SNS SMS)', () => {
    const statements = [
      ...policyStatementsFromResources(template.findResources('AWS::IAM::Policy')),
      ...policyStatementsFromResources(template.findResources('AWS::IAM::Role')),
    ];
    const actions = statements.flatMap((statement) => asArray(statement.Action));

    // SNS Publish for SMS requires resources: ['*'] because targets are phone numbers,
    // not ARN resources. This is an AWS limitation. Filter these out.
    const nonSnsStatements = statements.filter((statement) => {
      const statementActions = asArray(statement.Action);
      return !statementActions.some((a) => typeof a === 'string' && a === 'sns:Publish');
    });
    const resources = nonSnsStatements.flatMap((statement) => asArray(statement.Resource));

    expect(actions).not.toContain('*');
    expect(resources).not.toContain('*');
  });
});
