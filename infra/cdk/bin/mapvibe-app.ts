#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { MapVibeStack } from '../lib/mapvibe-stack';

const app = new cdk.App();

const stage = app.node.tryGetContext('stage') || 'dev';

new MapVibeStack(app, `MapVibe-${stage}`, {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: 'ap-southeast-1',
  },
  stage,
});
