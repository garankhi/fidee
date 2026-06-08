import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /journey/checkins
 * Fetch user's own check-ins (history).
 * Query params:
 *   - cursor (ISO timestamp, optional): pagination cursor
 *   - limit (int, optional, default 20, max 50)
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    let userId: string;
    try {
      const auth = await extractAuth(event);
      userId = auth.sub;
    } catch {
      return {
        statusCode: 401,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    let limit = parseInt(event.queryStringParameters?.limit || '20', 10);
    if (isNaN(limit) || limit <= 0) limit = 20;
    if (limit > 50) limit = 50;

    const cursor = event.queryStringParameters?.cursor || null;

    let cursorFilter = '';
    const params: any[] = [userId, limit + 1];
    if (cursor) {
      cursorFilter = `AND ci.created_at < $3`;
      params.push(cursor);
    }

    const sql = `
      SELECT
        ci.id,
        ci.caption,
        ci.rating,
        ci.created_at as "createdAt",
        ci.media_id as "mediaId",
        COALESCE(p.id, pc.id)::text as "placeId",
        COALESCE(p.name, pc.name) as "placeName",
        COALESCE(p.category, pc.category) as category
      FROM check_ins ci
      LEFT JOIN places p ON p.id = ci.place_id
      LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
      WHERE ci.user_id = $1
        ${cursorFilter}
      ORDER BY ci.created_at DESC
      LIMIT $2;
    `;

    const result = await query(sql, params);

    const hasMore = result.rows.length > limit;
    const data = hasMore ? result.rows.slice(0, limit) : result.rows;
    const nextCursor = hasMore ? data[data.length - 1].createdAt : null;

    // Map UI mock fields (like saved spots and tags) to null/empty for now,
    // as they are not natively supported by the schema.
    const mappedData = data.map(row => ({
      ...row,
      tags: [], // Could be extracted from text or vibes
      friendsSavedCount: 0,
    }));

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: mappedData,
        pagination: {
          nextCursor,
          hasMore,
        },
      }),
    };
  } catch (error) {
    console.error('Error fetching journey check-ins:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
