import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /journey/reviews
 * Fetch user's own reviews (history).
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
      cursorFilter = `AND r.created_at < $3`;
      params.push(cursor);
    }

    const sql = `
      SELECT
        r.id,
        r.rating,
        r.content,
        r.created_at as "createdAt",
        COALESCE(p.id, pc.id)::text as "placeId",
        COALESCE(p.name, pc.name) as "placeName",
        COALESCE(p.category, pc.category) as category,
        COALESCE(p.cover_media_id, pc.media_id) as "coverMediaId"
      FROM reviews r
      LEFT JOIN places p ON p.id = r.place_id
      LEFT JOIN place_candidates pc ON pc.id = r.candidate_id
      WHERE r.user_id = $1
        ${cursorFilter}
      ORDER BY r.created_at DESC
      LIMIT $2;
    `;

    const result = await query(sql, params);

    const hasMore = result.rows.length > limit;
    const data = hasMore ? result.rows.slice(0, limit) : result.rows;
    const nextCursor = hasMore ? data[data.length - 1].createdAt : null;

    // Map UI mock fields
    const mappedData = data.map(row => ({
      ...row,
      tags: [], // Could be extracted from content or metadata
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
    console.error('Error fetching journey reviews:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
