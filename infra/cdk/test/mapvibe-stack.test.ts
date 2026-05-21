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
    template.resourceCountIs('AWS::DynamoDB::Table', 1);
    template.resourceCountIs('AWS::S3::Bucket', 1);
    template.resourceCountIs('AWS::CloudFront::Distribution', 1);
    template.resourceCountIs('AWS::ApiGateway::RestApi', 1);
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'mapvibe-dev-search',
    });
    mediaTemplate.resourceCountIs('AWS::WAFv2::WebACL', 1);
    template.resourceCountIs('AWS::WAFv2::WebACL', 1);
  });

  it('names dev resources with mapvibe-dev prefix', () => {
    template.hasResourceProperties('AWS::Cognito::UserPool', {
      UserPoolName: 'mapvibe-dev-users',
    });
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'mapvibe-dev-places',
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

  it('does not write wildcard IAM actions', () => {
    const policies = template.findResources('AWS::IAM::Policy');
    const actions = Object.values(policies).flatMap((policy) => {
      const statements = policy.Properties.PolicyDocument.Statement;
      return statements.flatMap((statement: { Action: string | string[] }) => statement.Action);
    });

    expect(actions).not.toContain('*');
  });
});
