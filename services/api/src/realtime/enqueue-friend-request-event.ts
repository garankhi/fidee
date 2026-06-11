import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';

const dynamo = new DynamoDBClient({});

export interface FriendRequestRealtimeEventInput {
  type?: 'FRIEND_REQUEST_RECEIVED' | 'FRIEND_REQUEST_CANCELED';
  requesterId: string;
  requesterName: string;
  requesterUsername?: string | null;
  requesterAvatarUrl?: string | null;
  targetUserId: string;
  createdAt: string;
}

export async function enqueueFriendRequestRealtimeEvent(
  input: FriendRequestRealtimeEventInput,
): Promise<void> {
  const tableName = process.env.FRIEND_REQUEST_REALTIME_EVENTS_TABLE;
  if (!tableName) return;

  const eventType = input.type ?? 'FRIEND_REQUEST_RECEIVED';
  const eventPrefix = eventType === 'FRIEND_REQUEST_CANCELED'
    ? 'friend_request_canceled'
    : 'friend_request';
  const eventId = `${eventPrefix}#${input.requesterId}#${input.targetUserId}#${input.createdAt}`;
  const ttlDays = 7;
  const expiresAt = Math.floor(Date.now() / 1000) + ttlDays * 24 * 60 * 60;

  await dynamo.send(
    new PutItemCommand({
      TableName: tableName,
      ConditionExpression: 'attribute_not_exists(eventId)',
      Item: {
        eventId: { S: eventId },
        type: { S: eventType },
        targetUserId: { S: input.targetUserId },
        requesterId: { S: input.requesterId },
        requesterName: { S: input.requesterName },
        requesterUsername: { S: input.requesterUsername ?? '' },
        requesterAvatarUrl: { S: input.requesterAvatarUrl ?? '' },
        createdAt: { S: input.createdAt },
        expiresAt: { N: String(expiresAt) },
      },
    }),
  );
}
