import { describe, it, expect } from 'vitest';
import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { MapVibeStack } from '../lib/mapvibe-stack';

describe('MapVibeStack', () => {
  const app = new cdk.App();
  const stack = new MapVibeStack(app, 'TestStack', {
    stage: 'dev',
    env: { account: '123456789012', region: 'ap-southeast-1' },
  });
  const template = Template.fromStack(stack);

  it('creates a Cognito User Pool', () => {
    template.resourceCountIs('AWS::Cognito::UserPool', 1);
  });

  it('creates a DynamoDB table with PAY_PER_REQUEST billing', () => {
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      BillingMode: 'PAY_PER_REQUEST',
    });
  });

  it('creates an S3 bucket with public access blocked', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true,
      },
    });
  });

  it('creates a Lambda function', () => {
    template.resourceCountIs('AWS::Lambda::Function', 1);
  });

  it('creates an API Gateway', () => {
    template.resourceCountIs('AWS::ApiGateway::RestApi', 1);
  });
});
