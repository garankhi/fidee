import { GetItemCommand, PutItemCommand, DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { getPool, query } from '../db/client';
import { extractAuth } from '../middleware/auth';
import { enqueueChatRealtimeEvent, ChatRealtimeMessage } from '../realtime/chat-realtime-event';

const dynamo = new DynamoDBClient({});

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
};

function json(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

function readJsonBody(event: APIGatewayProxyEvent): Record<string, unknown> {
  if (!event.body) return {};
  return JSON.parse(event.body) as Record<string, unknown>;
}

function directKey(userA: string, userB: string): string {
  return [userA, userB].sort().join(':');
}

function clampLimit(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? '30', 10);
  if (!Number.isFinite(parsed)) return 30;
  return Math.min(Math.max(parsed, 1), 50);
}

async function isAcceptedFriend(userId: string, friendId: string): Promise<boolean> {
  const result = await query(
    `SELECT 1 FROM friendships
     WHERE user_id = $1 AND friend_id = $2 AND status = 'ACCEPTED'
     LIMIT 1`,
    [userId, friendId],
  );
  return (result.rowCount ?? 0) > 0;
}

async function assertParticipant(conversationId: string, userId: string): Promise<void> {
  const result = await query(
    `SELECT 1 FROM user_chat_participants
     WHERE conversation_id = $1 AND user_id = $2
     LIMIT 1`,
    [conversationId, userId],
  );
  if ((result.rowCount ?? 0) === 0) {
    throw Object.assign(new Error('Conversation not found'), { statusCode: 404 });
  }
}

async function getOtherParticipantIds(conversationId: string, userId: string): Promise<string[]> {
  const result = await query<{ user_id: string }>(
    `SELECT user_id FROM user_chat_participants
     WHERE conversation_id = $1 AND user_id <> $2`,
    [conversationId, userId],
  );
  return result.rows.map((row) => row.user_id);
}

async function assertCanSend(conversationId: string, userId: string): Promise<string[]> {
  await assertParticipant(conversationId, userId);
  const otherUserIds = await getOtherParticipantIds(conversationId, userId);
  for (const otherUserId of otherUserIds) {
    if (!(await isAcceptedFriend(userId, otherUserId))) {
      throw Object.assign(new Error('Only accepted friends can chat'), { statusCode: 403 });
    }
  }
  return otherUserIds;
}

function mapMessage(row: Record<string, unknown>): ChatRealtimeMessage {
  return {
    id: String(row.id),
    conversationId: String(row.conversation_id),
    senderId: String(row.sender_id),
    clientMessageId: String(row.client_message_id),
    body: String(row.body),
    status: String(row.status),
    createdAt: new Date(String(row.created_at)).toISOString(),
  };
}

export async function createDirectConversation(
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const body = readJsonBody(event);
    const targetUserId = typeof body.targetUserId === 'string' ? body.targetUserId.trim() : '';
    if (!targetUserId) return json(400, { error: 'targetUserId is required' });
    if (targetUserId === auth.sub) return json(400, { error: 'Cannot chat with yourself' });
    if (!(await isAcceptedFriend(auth.sub, targetUserId))) {
      return json(403, { error: 'Only accepted friends can chat' });
    }

    const pool = await getPool();
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const conversation = await client.query<{
        id: string;
        direct_key: string;
        created_at: string;
      }>(
        `INSERT INTO user_chat_conversations (direct_key, created_by)
         VALUES ($1, $2)
         ON CONFLICT (direct_key) DO UPDATE SET direct_key = EXCLUDED.direct_key
         RETURNING id, direct_key, created_at`,
        [directKey(auth.sub, targetUserId), auth.sub],
      );
      const conversationId = conversation.rows[0].id;
      await client.query(
        `INSERT INTO user_chat_participants (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3)
         ON CONFLICT (conversation_id, user_id) DO NOTHING`,
        [conversationId, auth.sub, targetUserId],
      );
      await client.query('COMMIT');

      return json(200, {
        conversation: {
          id: conversationId,
          type: 'DIRECT',
          directKey: conversation.rows[0].direct_key,
          createdAt: new Date(String(conversation.rows[0].created_at)).toISOString(),
        },
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    return handleError('createDirectConversation', error);
  }
}

export async function listConversations(
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const result = await query(
      `
        SELECT
          c.id,
          c.type,
          c.updated_at,
          other_user.id AS other_user_id,
          other_user.display_name AS other_name,
          other_user.username AS other_username,
          other_user.avatar_url AS other_avatar_url,
          m.id AS last_message_id,
          m.sender_id AS last_sender_id,
          m.body AS last_body,
          m.created_at AS last_created_at,
          COALESCE(unread.count, 0)::int AS unread_count
        FROM user_chat_participants me
        JOIN user_chat_conversations c ON c.id = me.conversation_id
        JOIN user_chat_participants other_p
          ON other_p.conversation_id = c.id AND other_p.user_id <> me.user_id
        JOIN users other_user ON other_user.id = other_p.user_id
        LEFT JOIN user_chat_messages m ON m.id = c.last_message_id
        LEFT JOIN LATERAL (
          SELECT COUNT(*) AS count
          FROM user_chat_messages unread_message
          WHERE unread_message.conversation_id = c.id
            AND unread_message.sender_id <> $1
            AND (
              me.last_read_message_id IS NULL
              OR unread_message.created_at > (
                SELECT created_at FROM user_chat_messages WHERE id = me.last_read_message_id
              )
            )
        ) unread ON TRUE
        WHERE me.user_id = $1 AND me.archived_at IS NULL
        ORDER BY c.updated_at DESC
      `,
      [auth.sub],
    );

    return json(200, {
      conversations: result.rows.map((row) => ({
        id: row.id,
        type: row.type,
        updatedAt: row.updated_at,
        unreadCount: row.unread_count,
        otherUser: {
          id: row.other_user_id,
          name: row.other_name,
          username: row.other_username,
          avatarUrl: row.other_avatar_url,
          presenceStatus: 'UNKNOWN',
        },
        lastMessage: row.last_message_id
          ? {
              id: row.last_message_id,
              senderId: row.last_sender_id,
              body: row.last_body,
              createdAt: row.last_created_at,
            }
          : null,
      })),
    });
  } catch (error) {
    return handleError('listConversations', error);
  }
}

export async function listMessages(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const conversationId = event.pathParameters?.conversationId ?? '';
    if (!conversationId) return json(400, { error: 'conversationId is required' });
    await assertParticipant(conversationId, auth.sub);

    const limit = clampLimit(event.queryStringParameters?.limit);
    const before = event.queryStringParameters?.before;
    const params: unknown[] = [conversationId, limit];
    let beforeClause = '';
    if (before) {
      params.push(before);
      beforeClause = 'AND created_at < $3::timestamptz';
    }

    const result = await query(
      `
        SELECT * FROM (
          SELECT id, conversation_id, sender_id, client_message_id, body, status, created_at
          FROM user_chat_messages
          WHERE conversation_id = $1 ${beforeClause}
          ORDER BY created_at DESC
          LIMIT $2
        ) page
        ORDER BY created_at ASC
      `,
      params,
    );

    return json(200, { messages: result.rows.map(mapMessage) });
  } catch (error) {
    return handleError('listMessages', error);
  }
}

export async function sendMessage(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const conversationId = event.pathParameters?.conversationId ?? '';
    const body = readJsonBody(event);
    const clientMessageId =
      typeof body.clientMessageId === 'string' ? body.clientMessageId.trim() : '';
    const messageBody = typeof body.body === 'string' ? body.body.trim() : '';
    if (!conversationId) return json(400, { error: 'conversationId is required' });
    if (!clientMessageId) return json(400, { error: 'clientMessageId is required' });
    if (!messageBody || messageBody.length > 2000) {
      return json(400, { error: 'body must be 1-2000 characters' });
    }

    const recipientIds = await assertCanSend(conversationId, auth.sub);
    const pool = await getPool();
    const client = await pool.connect();
    let inserted = false;
    let message: ChatRealtimeMessage;
    try {
      await client.query('BEGIN');
      const messageResult = await client.query(
        `
          WITH inserted AS (
            INSERT INTO user_chat_messages (conversation_id, sender_id, client_message_id, body)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (sender_id, client_message_id) DO NOTHING
            RETURNING *, TRUE AS inserted
          ), existing AS (
            SELECT *, FALSE AS inserted
            FROM user_chat_messages
            WHERE sender_id = $2 AND client_message_id = $3
              AND NOT EXISTS (SELECT 1 FROM inserted)
          )
          SELECT * FROM inserted
          UNION ALL
          SELECT * FROM existing
        `,
        [conversationId, auth.sub, clientMessageId, messageBody],
      );
      const row = messageResult.rows[0] as Record<string, unknown> & { inserted?: boolean };
      inserted = row.inserted === true;
      message = mapMessage(row);

      if (inserted) {
        await client.query(
          `UPDATE user_chat_conversations
           SET last_message_id = $1, updated_at = NOW()
           WHERE id = $2`,
          [message.id, conversationId],
        );
        await client.query(
          `INSERT INTO user_chat_message_receipts (message_id, user_id, delivered_at)
           SELECT $1, user_id, CASE WHEN user_id = $2 THEN NOW() ELSE NULL END
           FROM user_chat_participants
           WHERE conversation_id = $3
           ON CONFLICT (message_id, user_id) DO NOTHING`,
          [message.id, auth.sub, conversationId],
        );
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    if (inserted) {
      await Promise.all(
        recipientIds.map((targetUserId) =>
          enqueueChatRealtimeEvent({
            type: 'MESSAGE_CREATED',
            targetUserId,
            conversationId,
            message,
            createdAt: new Date().toISOString(),
          }),
        ),
      );
    }

    return json(200, { message, inserted });
  } catch (error) {
    return handleError('sendMessage', error);
  }
}

export async function markRead(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const conversationId = event.pathParameters?.conversationId ?? '';
    const body = readJsonBody(event);
    const messageId = typeof body.messageId === 'string' ? body.messageId.trim() : '';
    if (!conversationId) return json(400, { error: 'conversationId is required' });
    if (!messageId) return json(400, { error: 'messageId is required' });
    await assertCanSend(conversationId, auth.sub);

    const messageResult = await query<{ id: string }>(
      `SELECT id FROM user_chat_messages WHERE id = $1 AND conversation_id = $2`,
      [messageId, conversationId],
    );
    if ((messageResult.rowCount ?? 0) === 0) return json(404, { error: 'Message not found' });

    await query(
      `INSERT INTO user_chat_message_receipts (message_id, user_id, delivered_at, read_at)
       VALUES ($1, $2, NOW(), NOW())
       ON CONFLICT (message_id, user_id) DO UPDATE
       SET delivered_at = COALESCE(user_chat_message_receipts.delivered_at, NOW()),
           read_at = NOW()`,
      [messageId, auth.sub],
    );
    await query(
      `UPDATE user_chat_participants
       SET last_read_message_id = $1
       WHERE conversation_id = $2 AND user_id = $3`,
      [messageId, conversationId, auth.sub],
    );

    const otherUserIds = await getOtherParticipantIds(conversationId, auth.sub);
    const now = new Date().toISOString();
    await Promise.all(
      otherUserIds.map((targetUserId) =>
        enqueueChatRealtimeEvent({
          type: 'MESSAGE_READ',
          targetUserId,
          conversationId,
          receipt: { conversationId, messageId, userId: auth.sub, readAt: now },
          createdAt: now,
        }),
      ),
    );

    return json(200, { success: true });
  } catch (error) {
    return handleError('markRead', error);
  }
}

export async function markDelivered(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const conversationId = event.pathParameters?.conversationId ?? '';
    const body = readJsonBody(event);
    const messageId = typeof body.messageId === 'string' ? body.messageId.trim() : '';
    if (!conversationId) return json(400, { error: 'conversationId is required' });
    if (!messageId) return json(400, { error: 'messageId is required' });
    await assertCanSend(conversationId, auth.sub);

    const messageResult = await query<{ id: string; sender_id: string }>(
      `SELECT id, sender_id FROM user_chat_messages WHERE id = $1 AND conversation_id = $2`,
      [messageId, conversationId],
    );
    if ((messageResult.rowCount ?? 0) === 0) return json(404, { error: 'Message not found' });

    await query(
      `INSERT INTO user_chat_message_receipts (message_id, user_id, delivered_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (message_id, user_id) DO UPDATE
       SET delivered_at = COALESCE(user_chat_message_receipts.delivered_at, NOW())`,
      [messageId, auth.sub],
    );

    const senderId = messageResult.rows[0].sender_id;
    if (senderId !== auth.sub) {
      const now = new Date().toISOString();
      await enqueueChatRealtimeEvent({
        type: 'MESSAGE_DELIVERED',
        targetUserId: senderId,
        conversationId,
        receipt: { conversationId, messageId, userId: auth.sub, deliveredAt: now },
        createdAt: now,
      });
    }

    return json(200, { success: true });
  } catch (error) {
    return handleError('markDelivered', error);
  }
}

export async function sendTyping(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const conversationId = event.pathParameters?.conversationId ?? '';
    const body = readJsonBody(event);
    const isTyping = body.isTyping === true;
    if (!conversationId) return json(400, { error: 'conversationId is required' });
    const recipientIds = await assertCanSend(conversationId, auth.sub);
    const now = new Date().toISOString();

    await Promise.all(
      recipientIds.map((targetUserId) =>
        enqueueChatRealtimeEvent({
          type: 'TYPING',
          targetUserId,
          conversationId,
          typing: { conversationId, userId: auth.sub, isTyping },
          createdAt: now,
        }),
      ),
    );

    return json(200, { success: true });
  } catch (error) {
    return handleError('sendTyping', error);
  }
}

export async function heartbeat(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);
    const tableName = process.env.CHAT_PRESENCE_TABLE;
    if (!tableName) return json(200, { success: true });

    const body = readJsonBody(event);
    const deviceId = typeof body.deviceId === 'string' ? body.deviceId.trim() : 'default';
    const now = new Date().toISOString();
    const expiresAt = Math.floor(Date.now() / 1000) + 90;
    const previous = await dynamo.send(
      new GetItemCommand({
        TableName: tableName,
        Key: { userId: { S: auth.sub } },
        ProjectionExpression: '#status',
        ExpressionAttributeNames: { '#status': 'status' },
      }),
    );
    const previousStatus = previous.Item?.status?.S;
    await dynamo.send(
      new PutItemCommand({
        TableName: tableName,
        Item: {
          userId: { S: auth.sub },
          deviceId: { S: deviceId },
          status: { S: 'ONLINE' },
          lastSeenAt: { S: now },
          expiresAt: { N: String(expiresAt) },
        },
      }),
    );

    if (previousStatus !== 'ONLINE') {
      const friends = await query<{ friend_id: string }>(
        `SELECT friend_id FROM friendships WHERE user_id = $1 AND status = 'ACCEPTED'`,
        [auth.sub],
      );
      await Promise.all(
        friends.rows.map((row) =>
          enqueueChatRealtimeEvent({
            type: 'PRESENCE_CHANGED',
            targetUserId: row.friend_id,
            presence: { userId: auth.sub, status: 'ONLINE', lastSeenAt: now },
            createdAt: now,
          }),
        ),
      );
    }

    return json(200, { success: true, status: 'ONLINE', lastSeenAt: now });
  } catch (error) {
    return handleError('heartbeat', error);
  }
}

function handleError(label: string, error: unknown): APIGatewayProxyResult {
  console.error(`${label} error`, error);
  const statusCode =
    typeof error === 'object' && error !== null && 'statusCode' in error
      ? Number((error as { statusCode?: unknown }).statusCode)
      : 500;
  if (statusCode === 403) return json(403, { error: 'Forbidden' });
  if (statusCode === 404) return json(404, { error: 'Not found' });
  return json(500, { error: 'Internal server error' });
}
