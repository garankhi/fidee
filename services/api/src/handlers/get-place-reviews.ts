import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /places/{id}/reviews — Paginated reviews for a place or candidate.
 *
 * Query params:
 *   - cursor (ISO timestamp, optional): pagination cursor
 *   - limit (int, optional, default 20, max 50)
 *   - type (friends|all, optional, default all)
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

    const placeId = event.pathParameters?.id;
    if (!placeId) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Missing place id' }),
      };
    }

    // Parse params
    let limit = parseInt(event.queryStringParameters?.limit || '20', 10);
    if (isNaN(limit) || limit <= 0) limit = 20;
    if (limit > 50) limit = 50;

    const cursor = event.queryStringParameters?.cursor || null;
    const filterType = event.queryStringParameters?.type || 'all';

    // Determine if target is place or candidate
    const placeCheck = await query('SELECT id FROM places WHERE id = $1', [placeId]);
    const isPlace = placeCheck.rowCount! > 0;

    if (!isPlace) {
      const candidateCheck = await query('SELECT id FROM place_candidates WHERE id = $1', [
        placeId,
      ]);
      if (candidateCheck.rowCount === 0) {
        return {
          statusCode: 404,
          headers: CORS_HEADERS,
          body: JSON.stringify({ error: 'Place not found' }),
        };
      }
    }

    const targetCol = isPlace ? 'r.place_id' : 'r.candidate_id';

    // Build friend filter
    let friendFilter = '';
    if (filterType === 'friends') {
      friendFilter = `
        AND r.user_id IN (
          SELECT friend_id FROM friendships
          WHERE user_id = '${userId}' AND status = 'ACCEPTED'
          UNION ALL SELECT '${userId}'
        )
      `;
    }

    // Build cursor filter
    let cursorFilter = '';
    const params: any[] = [placeId, limit + 1];
    if (cursor) {
      cursorFilter = 'AND r.created_at < $3';
      params.push(cursor);
    }

    const sql = `
      SELECT
        r.id,
        r.user_id AS "userId",
        u.display_name AS "userName",
        u.avatar_url AS "userAvatar",
        r.rating,
        r.content,
        r.is_featured AS "isFeatured",
        r.created_at AS "createdAt",
        CASE WHEN f.friend_id IS NOT NULL THEN true ELSE false END AS "isFriend"
      FROM reviews r
      JOIN users u ON u.id = r.user_id
      LEFT JOIN friendships f ON f.user_id = $1::text AND f.friend_id = r.user_id AND f.status = 'ACCEPTED'
      WHERE ${targetCol} = $1
        ${friendFilter}
        ${cursorFilter}
      ORDER BY r.created_at DESC
      LIMIT $2;
    `;

    // Fix: use userId for friend join, placeId for target
    const fixedSql = `
      SELECT
        r.id,
        r.user_id AS "userId",
        u.display_name AS "userName",
        u.avatar_url AS "userAvatar",
        r.rating,
        r.content,
        r.is_featured AS "isFeatured",
        r.created_at AS "createdAt",
        CASE WHEN EXISTS (
          SELECT 1 FROM friendships
          WHERE user_id = '${userId}' AND friend_id = r.user_id AND status = 'ACCEPTED'
        ) THEN true ELSE false END AS "isFriend"
      FROM reviews r
      JOIN users u ON u.id = r.user_id
      WHERE ${targetCol} = $1
        ${friendFilter}
        ${cursorFilter}
      ORDER BY r.created_at DESC
      LIMIT $2;
    `;

    const result = await query(fixedSql, params);

    const hasMore = result.rows.length > limit;
    const data = hasMore ? result.rows.slice(0, limit) : result.rows;
    const nextCursor = hasMore ? data[data.length - 1].createdAt : null;

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data,
        pagination: {
          nextCursor,
          hasMore,
        },
      }),
    };
  } catch (error) {
    console.error('Error fetching reviews:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
