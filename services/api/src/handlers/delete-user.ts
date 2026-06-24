import {
  AdminDeleteUserCommand,
  CognitoIdentityProviderClient,
  UserNotFoundException,
} from '@aws-sdk/client-cognito-identity-provider';
import { DeleteCommand, DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { PoolClient } from 'pg';
import { getPool } from '../db/client';
import { extractAuth } from '../middleware/auth';

const cognitoClient = new CognitoIdentityProviderClient({});
const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
};

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify(body),
  };
}

function isAdmin(groups: string[]): boolean {
  return groups.includes('Admins');
}

async function deleteDynamoProfile(userId: string): Promise<void> {
  const tableName = process.env.USER_PROFILES_TABLE;
  if (!tableName) return;

  try {
    await dynamoClient.send(
      new DeleteCommand({
        TableName: tableName,
        Key: { userId },
      }),
    );
  } catch (error) {
    console.error(`[Delete User] Failed to delete DynamoDB profile for ${userId}`, error);
  }
}

async function deleteCognitoUser(cognitoUsername: string): Promise<void> {
  const userPoolId = process.env.COGNITO_USER_POOL_ID;
  if (!userPoolId) return;

  try {
    await cognitoClient.send(
      new AdminDeleteUserCommand({
        UserPoolId: userPoolId,
        Username: cognitoUsername,
      }),
    );
  } catch (error) {
    if (error instanceof UserNotFoundException) return;
    console.error(`[Delete User] Failed to delete Cognito user ${cognitoUsername}`, error);
    throw error;
  }
}

async function tableExists(client: PoolClient, tableName: string): Promise<boolean> {
  const result = await client.query('SELECT to_regclass($1) AS table_name', [`public.${tableName}`]);
  return result.rows[0]?.table_name != null;
}

async function queryIfTableExists(
  client: PoolClient,
  tableName: string,
  sql: string,
  params: unknown[],
): Promise<void> {
  if (await tableExists(client, tableName)) {
    await client.query(sql, params);
  }
}

interface DeletedUserSnapshot {
  email: string | null;
}

async function anonymizePostgresUser(userId: string): Promise<DeletedUserSnapshot | null> {
  const pool = await getPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const existing = await client.query<DeletedUserSnapshot>(
      'SELECT email FROM users WHERE id = $1 FOR UPDATE',
      [userId],
    );
    if (existing.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    const snapshot = existing.rows[0];

    await queryIfTableExists(
      client,
      'friendships',
      'DELETE FROM friendships WHERE user_id = $1 OR friend_id = $1',
      [userId],
    );
    await queryIfTableExists(client, 'user_settings', 'DELETE FROM user_settings WHERE user_id = $1', [
      userId,
    ]);
    await queryIfTableExists(
      client,
      'user_subscriptions',
      'DELETE FROM user_subscriptions WHERE user_id = $1',
      [userId],
    );
    await queryIfTableExists(client, 'ai_usage_daily', 'DELETE FROM ai_usage_daily WHERE user_id = $1', [
      userId,
    ]);
    await queryIfTableExists(client, 'comments', 'DELETE FROM comments WHERE user_id = $1', [userId]);
    await queryIfTableExists(client, 'reviews', 'DELETE FROM reviews WHERE user_id = $1', [userId]);
    await queryIfTableExists(
      client,
      'check_in_recipients',
      'DELETE FROM check_in_recipients WHERE recipient_user_id = $1',
      [userId],
    );
    await queryIfTableExists(client, 'check_ins', 'DELETE FROM check_ins WHERE user_id = $1', [userId]);
    await queryIfTableExists(
      client,
      'place_candidates',
      'DELETE FROM place_candidates WHERE created_by = $1',
      [userId],
    );
    await queryIfTableExists(
      client,
      'user_chat_message_receipts',
      'DELETE FROM user_chat_message_receipts WHERE user_id = $1',
      [userId],
    );
    await queryIfTableExists(
      client,
      'user_chat_participants',
      'DELETE FROM user_chat_participants WHERE user_id = $1',
      [userId],
    );
    await queryIfTableExists(
      client,
      'user_chat_messages',
      `
        UPDATE user_chat_messages
        SET body = '[deleted account]', status = 'DELETED', deleted_at = COALESCE(deleted_at, NOW())
        WHERE sender_id = $1
      `,
      [userId],
    );

    await client.query(
      `
        UPDATE users
        SET display_name = 'Người dùng đã xóa',
            username = NULL,
            avatar_url = NULL,
            bio = NULL,
            email = NULL,
            phone = NULL,
            auth_provider = 'deleted'
        WHERE id = $1
      `,
      [userId],
    );

    await client.query('COMMIT');
    return snapshot;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = event.pathParameters?.userId?.trim();

    if (!targetUserId) {
      return jsonResponse(400, { error: 'Missing userId in path', code: 'VALIDATION_ERROR' });
    }

    if (auth.sub !== targetUserId && !isAdmin(auth.groups)) {
      return jsonResponse(403, {
        error: 'Only admins or the account owner can delete this account',
        code: 'FORBIDDEN',
      });
    }

    const deletedUser = await anonymizePostgresUser(targetUserId);
    if (!deletedUser) {
      return jsonResponse(404, { error: 'User not found', code: 'NOT_FOUND' });
    }

    await deleteDynamoProfile(targetUserId);

    const cognitoUsername =
      auth.sub === targetUserId
        ? auth.username ?? deletedUser.email ?? auth.sub
        : deletedUser.email ?? targetUserId;
    if (auth.sub === targetUserId || isAdmin(auth.groups)) {
      await deleteCognitoUser(cognitoUsername);
    }

    return jsonResponse(200, { success: true, deletedUserId: targetUserId });
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Missing auth context')) {
      return jsonResponse(401, { error: error.message, code: 'UNAUTHORIZED' });
    }

    console.error('Failed to delete user', error);
    return jsonResponse(500, { error: 'Internal server error', code: 'INTERNAL_ERROR' });
  }
};
