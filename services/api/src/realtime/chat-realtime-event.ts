import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';

const dynamo = new DynamoDBClient({});

export type ChatRealtimeEventType =
  | 'MESSAGE_CREATED'
  | 'MESSAGE_DELIVERED'
  | 'MESSAGE_READ'
  | 'TYPING'
  | 'PRESENCE_CHANGED';

export interface ChatRealtimeMessage {
  id: string;
  conversationId: string;
  senderId: string;
  clientMessageId: string;
  body: string;
  status: string;
  createdAt: string;
}

export interface ChatRealtimeReceipt {
  conversationId: string;
  messageId: string;
  userId: string;
  deliveredAt?: string | null;
  readAt?: string | null;
}

export interface ChatRealtimeTyping {
  conversationId: string;
  userId: string;
  isTyping: boolean;
}

export interface ChatRealtimePresence {
  userId: string;
  status: string;
  lastSeenAt: string;
}

export interface ChatRealtimeEventInput {
  type: ChatRealtimeEventType;
  targetUserId: string;
  conversationId?: string | null;
  message?: ChatRealtimeMessage | null;
  receipt?: ChatRealtimeReceipt | null;
  typing?: ChatRealtimeTyping | null;
  presence?: ChatRealtimePresence | null;
  createdAt: string;
}

export async function enqueueChatRealtimeEvent(input: ChatRealtimeEventInput): Promise<void> {
  const tableName = process.env.CHAT_REALTIME_EVENTS_TABLE;
  if (!tableName) return;

  const eventId = [
    input.type.toLowerCase(),
    input.targetUserId,
    input.conversationId ?? input.presence?.userId ?? 'global',
    input.message?.id ?? input.receipt?.messageId ?? input.createdAt,
  ].join('#');
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
        conversationId: { S: input.conversationId ?? '' },
        message: { S: JSON.stringify(input.message ?? null) },
        receipt: { S: JSON.stringify(input.receipt ?? null) },
        typing: { S: JSON.stringify(input.typing ?? null) },
        presence: { S: JSON.stringify(input.presence ?? null) },
        createdAt: { S: input.createdAt },
        expiresAt: { N: String(expiresAt) },
      },
    }),
  );
}
