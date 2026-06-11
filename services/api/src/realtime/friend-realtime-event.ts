import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';

const dynamo = new DynamoDBClient({});

export type FriendRealtimeEventType =
  | 'FRIEND_REQUEST_RECEIVED'
  | 'FRIEND_REQUEST_CANCELED'
  | 'FRIEND_REQUEST_DECLINED'
  | 'FRIEND_REQUEST_ACCEPTED'
  | 'FRIENDSHIP_REMOVED'
  | 'FRIENDSHIP_HIDDEN'
  | 'FRIEND_BLOCKED';

export interface FriendRealtimeEventInput {
  type: FriendRealtimeEventType;
  targetUserId: string;
  actorUserId: string;
  relatedUserId: string;
  actorName: string;
  actorUsername?: string | null;
  actorAvatarUrl?: string | null;
  createdAt: string;
}

export async function enqueueFriendRealtimeEvent(input: FriendRealtimeEventInput): Promise<void> {
  const tableName = process.env.FRIEND_REQUEST_REALTIME_EVENTS_TABLE;
  if (!tableName) return;

  const eventPrefix = input.type.toLowerCase();
  const eventId = `${eventPrefix}#${input.targetUserId}#${input.actorUserId}#${input.createdAt}`;
  const ttlDays = 7;
  const expiresAt = Math.floor(Date.now() / 1000) + ttlDays * 24 * 60 * 60;

  await dynamo.send(
    new PutItemCommand({
      TableName: tableName,
      ConditionExpression: 'attribute_not_exists(eventId)',
      Item: {
        eventId: { S: eventId },
        type: { S: input.type },
        targetUserId: { S: input.targetUserId },
        actorUserId: { S: input.actorUserId },
        relatedUserId: { S: input.relatedUserId },
        actorName: { S: input.actorName },
        actorUsername: { S: input.actorUsername ?? '' },
        actorAvatarUrl: { S: input.actorAvatarUrl ?? '' },
        createdAt: { S: input.createdAt },
        expiresAt: { N: String(expiresAt) },
      },
    }),
  );
}
