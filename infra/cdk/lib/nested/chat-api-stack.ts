import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import { Construct } from 'constructs';

export interface ChatApiStackProps extends cdk.NestedStackProps {
  api: apigateway.IRestApi;
  authorizer: apigateway.IAuthorizer;
  vpc: ec2.IVpc;
  lambdaSecurityGroup: ec2.ISecurityGroup;
  dbSecret: secretsmanager.ISecret;
  chatRealtimeEventsTable: dynamodb.ITable;
  chatPresenceTable: dynamodb.ITable;
  stage: string;
}

const resourceName = (stage: string, resource: string) => `fidee-${stage}-${resource}`;

export class ChatApiStack extends cdk.NestedStack {
  constructor(scope: Construct, id: string, props: ChatApiStackProps) {
    super(scope, id, props);

    const { api, authorizer, vpc, lambdaSecurityGroup, dbSecret, chatRealtimeEventsTable, chatPresenceTable, stage } = props;

    const chatLambdaProps = {
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
        CHAT_REALTIME_EVENTS_TABLE: chatRealtimeEventsTable.tableName,
        CHAT_PRESENCE_TABLE: chatPresenceTable.tableName,
      },
      bundling: {
        nodeModules: ['pg'],
      },
    };

    const createDirectConversationFn = new nodejs.NodejsFunction(
      this,
      'CreateDirectConversationFunction',
      {
        ...chatLambdaProps,
        functionName: resourceName(stage, 'create-direct-conversation'),
        entry: '../../services/api/src/handlers/user-chat-handlers.ts',
        handler: 'createDirectConversation',
      },
    );
    dbSecret.grantRead(createDirectConversationFn);

    const listConversationsFn = new nodejs.NodejsFunction(this, 'ListConversationsFunction', {
      ...chatLambdaProps,
      functionName: resourceName(stage, 'list-conversations'),
      entry: '../../services/api/src/handlers/user-chat-handlers.ts',
      handler: 'listConversations',
    });
    dbSecret.grantRead(listConversationsFn);

    const listMessagesFn = new nodejs.NodejsFunction(this, 'ListMessagesFunction', {
      ...chatLambdaProps,
      functionName: resourceName(stage, 'list-chat-messages'),
      entry: '../../services/api/src/handlers/user-chat-handlers.ts',
      handler: 'listMessages',
    });
    dbSecret.grantRead(listMessagesFn);

    const sendMessageFn = new nodejs.NodejsFunction(this, 'SendChatMessageFunction', {
      ...chatLambdaProps,
      functionName: resourceName(stage, 'send-chat-message'),
      entry: '../../services/api/src/handlers/user-chat-handlers.ts',
      handler: 'sendMessage',
    });
    dbSecret.grantRead(sendMessageFn);
    chatRealtimeEventsTable.grantWriteData(sendMessageFn);

    const markChatReadFn = new nodejs.NodejsFunction(this, 'MarkChatReadFunction', {
      ...chatLambdaProps,
      functionName: resourceName(stage, 'mark-chat-read'),
      entry: '../../services/api/src/handlers/user-chat-handlers.ts',
      handler: 'markRead',
    });
    dbSecret.grantRead(markChatReadFn);
    chatRealtimeEventsTable.grantWriteData(markChatReadFn);

    const markChatDeliveredFn = new nodejs.NodejsFunction(this, 'MarkChatDeliveredFunction', {
      ...chatLambdaProps,
      functionName: resourceName(stage, 'mark-chat-delivered'),
      entry: '../../services/api/src/handlers/user-chat-handlers.ts',
      handler: 'markDelivered',
    });
    dbSecret.grantRead(markChatDeliveredFn);
    chatRealtimeEventsTable.grantWriteData(markChatDeliveredFn);

    const sendChatTypingFn = new nodejs.NodejsFunction(this, 'SendChatTypingFunction', {
      ...chatLambdaProps,
      functionName: resourceName(stage, 'send-chat-typing'),
      entry: '../../services/api/src/handlers/user-chat-handlers.ts',
      handler: 'sendTyping',
    });
    dbSecret.grantRead(sendChatTypingFn);
    chatRealtimeEventsTable.grantWriteData(sendChatTypingFn);

    const chatHeartbeatFn = new nodejs.NodejsFunction(this, 'ChatHeartbeatFunction', {
      ...chatLambdaProps,
      functionName: resourceName(stage, 'chat-heartbeat'),
      entry: '../../services/api/src/handlers/user-chat-handlers.ts',
      handler: 'heartbeat',
    });
    dbSecret.grantRead(chatHeartbeatFn);
    chatRealtimeEventsTable.grantWriteData(chatHeartbeatFn);
    chatPresenceTable.grantReadWriteData(chatHeartbeatFn);

    // ─── API Gateway Routes ─────────────────────────────
    const conversationsResource = api.root.addResource('conversations');
    conversationsResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    conversationsResource.addMethod('GET', new apigateway.LambdaIntegration(listConversationsFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const directConversationResource = conversationsResource.addResource('direct');
    directConversationResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    directConversationResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(createDirectConversationFn),
      {
        authorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const conversationResource = conversationsResource.addResource('{conversationId}');
    const conversationMessagesResource = conversationResource.addResource('messages');
    conversationMessagesResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['GET', 'POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    conversationMessagesResource.addMethod(
      'GET',
      new apigateway.LambdaIntegration(listMessagesFn),
      {
        authorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );
    conversationMessagesResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(sendMessageFn),
      {
        authorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const conversationReadResource = conversationResource.addResource('read');
    conversationReadResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    conversationReadResource.addMethod('POST', new apigateway.LambdaIntegration(markChatReadFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    const conversationDeliveredResource = conversationResource.addResource('delivered');
    conversationDeliveredResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    conversationDeliveredResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(markChatDeliveredFn),
      {
        authorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const conversationTypingResource = conversationResource.addResource('typing');
    conversationTypingResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    conversationTypingResource.addMethod(
      'POST',
      new apigateway.LambdaIntegration(sendChatTypingFn),
      {
        authorizer,
        authorizationType: apigateway.AuthorizationType.COGNITO,
      },
    );

    const presenceResource = api.root.addResource('presence');
    const heartbeatResource = presenceResource.addResource('heartbeat');
    heartbeatResource.addCorsPreflight({
      allowOrigins: apigateway.Cors.ALL_ORIGINS,
      allowMethods: ['POST', 'OPTIONS'],
      allowHeaders: ['Content-Type', 'Authorization'],
    });
    heartbeatResource.addMethod('POST', new apigateway.LambdaIntegration(chatHeartbeatFn), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });
  }
}
