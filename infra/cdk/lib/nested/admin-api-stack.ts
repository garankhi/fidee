import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import { Construct } from 'constructs';

export interface AdminApiStackProps extends cdk.NestedStackProps {
  api: apigateway.IRestApi;
  authorizer: apigateway.IAuthorizer;
  vpc: ec2.IVpc;
  lambdaSecurityGroup: ec2.ISecurityGroup;
  dbSecret: secretsmanager.ISecret;
  userProfilesTable: dynamodb.ITable;
  stage: string;
}

const resourceName = (stage: string, resource: string) => `fidee-${stage}-${resource}`;

export class AdminApiStack extends cdk.NestedStack {
  constructor(scope: Construct, id: string, props: AdminApiStackProps) {
    super(scope, id, props);

    const { api, authorizer, vpc, lambdaSecurityGroup, dbSecret, userProfilesTable, stage } = props;

    // Shared Lambda config for admin place handlers
    const adminLambdaProps = {
      runtime: lambda.Runtime.NODEJS_20_X,
      memorySize: 256,
      timeout: cdk.Duration.seconds(10),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSecurityGroup],
      environment: {
        STAGE: stage,
        DB_SECRET_ARN: dbSecret.secretArn,
        DB_NAME: 'fidee',
        GEMINI_API_KEYS: process.env.GEMINI_API_KEYS || process.env.GEMINI_API_KEY || '',
      },
      bundling: {
        nodeModules: ['pg'],
      },
    };

    // GET /admin/users
    const getUsersFn = new nodejs.NodejsFunction(this, 'GetUsersFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'get-users'),
      entry: '../../services/api/src/handlers/get-users.ts',
      handler: 'handler',
    });
    dbSecret.grantRead(getUsersFn);

    // PUT /admin/users/{userId}
    const updateUserFn = new nodejs.NodejsFunction(this, 'UpdateUserFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'update-user'),
      entry: '../../services/api/src/handlers/update-user.ts',
      handler: 'handler',
      environment: {
        ...adminLambdaProps.environment,
        USER_PROFILES_TABLE: userProfilesTable.tableName,
      },
    });
    dbSecret.grantRead(updateUserFn);
    userProfilesTable.grantReadWriteData(updateUserFn);

    // GET /admin/places/pending
    const getPendingPlacesFn = new nodejs.NodejsFunction(this, 'GetPendingPlacesFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'get-pending-places'),
      entry: '../../services/api/src/handlers/admin/get-pending-places.ts',
      handler: 'handler',
    });
    dbSecret.grantRead(getPendingPlacesFn);

    // GET /admin/places/candidates/{id}
    const getCandidateDetailFn = new nodejs.NodejsFunction(this, 'GetCandidateDetailFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'get-candidate-detail'),
      entry: '../../services/api/src/handlers/admin/get-candidate-detail.ts',
      handler: 'handler',
    });
    dbSecret.grantRead(getCandidateDetailFn);

    // POST /admin/places/candidates/{id}/approve
    // Needs PRIVATE_WITH_EGRESS for Gemini embedding API call
    const approveCandidateFn = new nodejs.NodejsFunction(this, 'ApproveCandidateFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'approve-candidate'),
      entry: '../../services/api/src/handlers/admin/approve-candidate.ts',
      handler: 'handler',
      timeout: cdk.Duration.seconds(30),
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      environment: {
        ...adminLambdaProps.environment,
        GEMINI_API_KEYS: process.env.GEMINI_API_KEYS || process.env.GEMINI_API_KEY || '',
      },
      bundling: {
        nodeModules: ['pg', '@google/genai'],
      },
    });
    dbSecret.grantRead(approveCandidateFn);

    // POST /admin/places/candidates/{id}/reject
    const rejectCandidateFn = new nodejs.NodejsFunction(this, 'RejectCandidateFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'reject-candidate'),
      entry: '../../services/api/src/handlers/admin/reject-candidate.ts',
      handler: 'handler',
    });
    dbSecret.grantRead(rejectCandidateFn);

    // POST /admin/places/candidates/{id}/merge
    const mergeCandidateFn = new nodejs.NodejsFunction(this, 'MergeCandidateFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'merge-candidate'),
      entry: '../../services/api/src/handlers/admin/merge-candidate.ts',
      handler: 'handler',
    });
    dbSecret.grantRead(mergeCandidateFn);

    // POST /admin/places/candidates/{id}/request-info
    const requestInfoCandidateFn = new nodejs.NodejsFunction(this, 'RequestInfoCandidateFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'request-info-candidate'),
      entry: '../../services/api/src/handlers/admin/request-info-candidate.ts',
      handler: 'handler',
    });
    dbSecret.grantRead(requestInfoCandidateFn);

    // Backfill Embeddings Lambda (invoke manually, not exposed via API Gateway)
    // Needs PRIVATE_WITH_EGRESS for Gemini embedding API + DB access
    const backfillEmbeddingsFn = new nodejs.NodejsFunction(this, 'BackfillEmbeddingsFunction', {
      ...adminLambdaProps,
      functionName: resourceName(stage, 'backfill-embeddings'),
      entry: '../../services/api/src/handlers/admin/backfill-embeddings.ts',
      handler: 'handler',
      memorySize: 512,
      timeout: cdk.Duration.seconds(300),
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      environment: {
        ...adminLambdaProps.environment,
        GEMINI_API_KEYS: process.env.GEMINI_API_KEYS || process.env.GEMINI_API_KEY || '',
      },
      bundling: {
        nodeModules: ['pg', '@google/genai'],
      },
    });
    dbSecret.grantRead(backfillEmbeddingsFn);

    // ─── Admin Places API Resources ─────────────────────────────
    const adminResource = api.root.addResource('admin');

    const adminUsersResource = adminResource.addResource('users');
    adminUsersResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminUsersResource.addMethod('GET', new apigateway.LambdaIntegration(getUsersFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const adminUserDetailResource = adminUsersResource.addResource('{userId}');
    adminUserDetailResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['PUT', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminUserDetailResource.addMethod('PUT', new apigateway.LambdaIntegration(updateUserFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const adminPlacesResource = adminResource.addResource('places');

    // /admin/places/pending
    const adminPendingResource = adminPlacesResource.addResource('pending');
    adminPendingResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminPendingResource.addMethod('GET', new apigateway.LambdaIntegration(getPendingPlacesFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // /admin/places/candidates/{id}
    const adminCandidatesResource = adminPlacesResource.addResource('candidates');
    const adminCandidateDetailResource = adminCandidatesResource.addResource('{id}');
    adminCandidateDetailResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminCandidateDetailResource.addMethod(
      'GET',
      new apigateway.LambdaIntegration(getCandidateDetailFn),
      {
        authorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    // /admin/places/candidates/{id}/approve
    const adminApproveResource = adminCandidateDetailResource.addResource('approve');
    adminApproveResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminApproveResource.addMethod('POST', new apigateway.LambdaIntegration(approveCandidateFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // /admin/places/candidates/{id}/reject
    const adminRejectResource = adminCandidateDetailResource.addResource('reject');
    adminRejectResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminRejectResource.addMethod('POST', new apigateway.LambdaIntegration(rejectCandidateFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // /admin/places/candidates/{id}/merge
    const adminMergeResource = adminCandidateDetailResource.addResource('merge');
    adminMergeResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminMergeResource.addMethod('POST', new apigateway.LambdaIntegration(mergeCandidateFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const adminRequestInfoResource = adminCandidateDetailResource.addResource('request-info');
    adminRequestInfoResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    adminRequestInfoResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(requestInfoCandidateFn),
      {
        authorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );
  }
}
