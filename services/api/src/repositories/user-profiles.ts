import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

export type UserPlan = 'FREE' | 'PRO';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export function normalizeUserPlan(value: unknown): UserPlan {
  return value === 'PRO' ? 'PRO' : 'FREE';
}

export async function getUserPlan(
  userId: string,
  tableName: string,
  client: DynamoDBDocumentClient = dynamoClient,
): Promise<UserPlan> {
  const result = await client.send(
    new GetCommand({
      TableName: tableName,
      Key: { userId },
      ProjectionExpression: '#plan',
      ExpressionAttributeNames: { '#plan': 'plan' },
    }),
  );

  return normalizeUserPlan(result.Item?.plan);
}
