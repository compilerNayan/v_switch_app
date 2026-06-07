#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { WaterMeterStack } from '../lib/water-meter-stack';

const app = new cdk.App();

new WaterMeterStack(app, 'WaterMeterStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION ?? 'us-east-1',
  },
});
