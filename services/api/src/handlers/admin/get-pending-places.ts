import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    // Basic Auth Check (In real app, verify admin group claims)
    const userId = event.requestContext.authorizer?.jwt?.claims?.sub
      || event.requestContext.authorizer?.claims?.sub;
    if (!userId) {
      return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
    }

    // List pending candidates from place_candidates
    // Join with users to get creator info
    const sql = `
      SELECT
        pc.id,
        pc.name,
        pc.category,
        pc.media_id,
        pc.created_at,
        u.display_name AS created_by_name
      FROM place_candidates pc
      JOIN users u ON pc.created_by = u.id
      ORDER BY pc.created_at DESC
      LIMIT 50;
    `;
    const result = await query(sql, []);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: result.rows,
      }),
    };
  } catch (error) {
    console.error('Error listing pending places:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
