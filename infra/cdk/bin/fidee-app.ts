#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
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
});

appStack.addDependency(mediaWafStack);
