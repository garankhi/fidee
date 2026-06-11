import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);

    const sql = `
      SELECT
        u.id,
        u.display_name,
        u.username,
        u.avatar_url,
        f.is_close_friend
      FROM friendships f
      JOIN users u ON f.friend_id = u.id
      WHERE f.user_id = $1 AND f.status = 'ACCEPTED'
      ORDER BY u.display_name ASC;
    `;
    const result = await query(sql, [auth.sub]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: result.rows,
      }),
    };
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Missing auth context')) {
      return {
        statusCode: 401,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }
    console.error('Failed to get friends:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
