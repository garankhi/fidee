import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth, maskPhone, maskEmail } from '../middleware/auth';
import { query } from '../db/client';

/**
 * GET /profile — returns the authenticated user's profile from JWT claims & DB.
 * Protected by Cognito JWT Authorizer.
 *
 * Returns: { sub, phone (masked), email (masked), groups, displayName, username, avatarUrl, plan, createdAt, friendCount }
 */
export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);

    const userResult = await query(
      'SELECT display_name, username, avatar_url, plan, created_at, friend_count FROM users WHERE id = $1',
      [auth.sub]
    );

    let dbUser: {
      displayName: string;
      username: string | null;
      avatarUrl: string | null;
      plan: string;
      createdAt: string;
      friendCount: number;
    } = {
      displayName: 'User',
      username: null,
      avatarUrl: null,
      plan: 'FREE',
      createdAt: new Date().toISOString(),
      friendCount: 0
    };

    if (userResult && userResult.rowCount && userResult.rowCount > 0) {
      const row = userResult.rows[0] as any;
      dbUser = {
        displayName: row.display_name || 'User',
        username: row.username || null,
        avatarUrl: row.avatar_url || null,
        plan: row.plan || 'FREE',
        createdAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
        friendCount: Number(row.friend_count) || 0
      };
    }

    return {
      statusCode: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,OPTIONS'
      },
      body: JSON.stringify({
        sub: auth.sub,
        phone: auth.phone ? maskPhone(auth.phone) : null,
        email: auth.email ? maskEmail(auth.email) : null,
        groups: auth.groups,
        ...dbUser
      }),
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unauthorized';
    const statusCode = message.startsWith('Forbidden') ? 403 : 401;

    return {
      statusCode,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: message }),
    };
  }
};
