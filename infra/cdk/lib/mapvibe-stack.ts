import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import { Construct } from 'constructs';

export interface MapVibeStackProps extends cdk.StackProps {
  stage: string;
}

export class MapVibeStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: MapVibeStackProps) {
    super(scope, id, props);

    const { stage } = props;

    // ─── Cognito User Pool ───────────────────────────────────────
    const userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: `mapvibe-users-${stage}`,
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      passwordPolicy: {
        minLength: 8,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: false,
      },
      removalPolicy: stage === 'prod' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });

    const userPoolClient = userPool.addClient('WebClient', {
      authFlows: { userSrp: true },
    });

    // ─── DynamoDB — Places Table ─────────────────────────────────
    const placesTable = new dynamodb.Table(this, 'PlacesTable', {
      tableName: `mapvibe-places-${stage}`,
      partitionKey: { name: 'PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'SK', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: stage === 'prod' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });

    placesTable.addGlobalSecondaryIndex({
      indexName: 'GSI1',
      partitionKey: { name: 'GSI1PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'GSI1SK', type: dynamodb.AttributeType.STRING },
    });

    // ─── S3 — Media Bucket ───────────────────────────────────────
    const mediaBucket = new s3.Bucket(this, 'MediaBucket', {
      bucketName: `mapvibe-media-${stage}-${this.account}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      removalPolicy: stage === 'prod' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: stage !== 'prod',
    });

    // ─── Lambda — Search Handler ─────────────────────────────────
    const searchFn = new lambda.Function(this, 'SearchFunction', {
      functionName: `mapvibe-search-${stage}`,
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'handlers/search.handler',
      code: lambda.Code.fromAsset('../../services/api/dist'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(30),
      environment: {
        STAGE: stage,
        PLACES_TABLE: placesTable.tableName,
        MEDIA_BUCKET: mediaBucket.bucketName,
      },
    });

    placesTable.grantReadData(searchFn);

    // ─── API Gateway ─────────────────────────────────────────────
    const api = new apigateway.RestApi(this, 'Api', {
      restApiName: `mapvibe-api-${stage}`,
      deployOptions: { stageName: stage },
    });

    const searchResource = api.root.addResource('search');
    searchResource.addMethod('POST', new apigateway.LambdaIntegration(searchFn));

    // ─── Outputs ─────────────────────────────────────────────────
    new cdk.CfnOutput(this, 'ApiUrl', { value: api.url });
    new cdk.CfnOutput(this, 'UserPoolId', { value: userPool.userPoolId });
    new cdk.CfnOutput(this, 'UserPoolClientId', { value: userPoolClient.userPoolClientId });
    new cdk.CfnOutput(this, 'PlacesTableName', { value: placesTable.tableName });
    new cdk.CfnOutput(this, 'MediaBucketName', { value: mediaBucket.bucketName });
  }
}
