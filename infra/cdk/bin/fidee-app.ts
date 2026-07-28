#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables from the root .env file
dotenv.config({ path: path.join(__dirname, '../../../.env') });

import {
  assertFideeStage,
  CLOUDFRONT_WAF_REGION,
  MAIN_REGION,
  FideeMediaWafStack,
  FideeStack,
} from '../lib/fidee-stack';

const app = new cdk.App();

const stage = assertFideeStage(app.node.tryGetContext('stage') ?? 'dev');
const account = process.env.CDK_DEFAULT_ACCOUNT;

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required for CDK synthesis`);
  }
  return value;
}

const googleWebClientId = requiredEnvironment('GOOGLE_CLIENT_ID');
const revenueCatProjectId = requiredEnvironment('REVENUECAT_PROJECT_ID');
const revenueCatProEntitlementId = requiredEnvironment(
  'REVENUECAT_PRO_ENTITLEMENT_ID',
);
const revenueCatTimeoutMs = Number(
  process.env.REVENUECAT_TIMEOUT_MS ?? '5000',
);
if (!Number.isFinite(revenueCatTimeoutMs) || revenueCatTimeoutMs <= 0) {
  throw new Error('REVENUECAT_TIMEOUT_MS must be a positive number');
}

const mediaWafStack = new FideeMediaWafStack(app, `Fidee-${stage}-MediaWaf`, {
  env: {
    account,
    region: CLOUDFRONT_WAF_REGION,
  },
  crossRegionReferences: true,
  stage,
});

const appStack = new FideeStack(app, `Fidee-${stage}`, {
  env: {
    account,
    region: MAIN_REGION,
  },
  crossRegionReferences: true,
  mediaWebAclArn: mediaWafStack.webAclArn,
  stage,
  googleWebClientId,
  revenueCatProjectId,
  revenueCatProEntitlementId,
  revenueCatTimeoutMs,
});

appStack.addDependency(mediaWafStack);
