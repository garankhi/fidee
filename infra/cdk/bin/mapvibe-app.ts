#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import {
  assertMapVibeStage,
  CLOUDFRONT_WAF_REGION,
  MAIN_REGION,
  MapVibeMediaWafStack,
  MapVibeStack,
} from '../lib/mapvibe-stack';

const app = new cdk.App();

const stage = assertMapVibeStage(app.node.tryGetContext('stage') ?? 'dev');
const account = process.env.CDK_DEFAULT_ACCOUNT;

const mediaWafStack = new MapVibeMediaWafStack(app, `MapVibe-${stage}-MediaWaf`, {
  env: {
    account,
    region: CLOUDFRONT_WAF_REGION,
  },
  crossRegionReferences: true,
  stage,
});

const appStack = new MapVibeStack(app, `MapVibe-${stage}`, {
  env: {
    account,
    region: MAIN_REGION,
  },
  crossRegionReferences: true,
  mediaWebAclArn: mediaWafStack.webAclArn,
  stage,
});

appStack.addDependency(mediaWafStack);
