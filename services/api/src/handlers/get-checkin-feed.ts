import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /feed/checkins
 * Fetch check-ins for social feed (everyone/friends).
 * Query params:
 *   - cursor (ISO timestamp, optional): pagination cursor
 *   - limit (int, optional, default 20, max 50)
 *   - filter (everyone|friends|me, default everyone)
 *   - friendId (optional): only show one accepted friend's check-ins
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
    const requestedFilter = event.queryStringParameters?.filter || 'everyone';
    const filter = ['everyone', 'friends', 'me'].includes(requestedFilter)
      ? requestedFilter
      : 'everyone';
    const friendId = event.queryStringParameters?.friendId?.trim() || null;

    const params: any[] = [userId, limit + 1];
    const pushParam = (value: unknown): string => {
      params.push(value);
      return `$${params.length}`;
    };

    let cursorFilter = '';
    if (cursor) {
      cursorFilter = `AND ci.created_at < ${pushParam(cursor)}`;
    }

    let visibilityFilter = '';
    if (friendId) {
      const friendParam = pushParam(friendId);
      visibilityFilter = `
        ci.visibility = 'FRIENDS'
        AND ci.user_id = ${friendParam}
        AND EXISTS (
          SELECT 1 FROM friendships f
          WHERE f.user_id = $1
            AND f.friend_id = ${friendParam}
            AND f.status = 'ACCEPTED'
        )
        AND (
          ci.audience_type = 'ALL_FRIENDS'
          OR EXISTS (
            SELECT 1 FROM check_in_recipients cir
            WHERE cir.checkin_id = ci.id
              AND cir.recipient_user_id = $1
          )
        )
      `;
    } else if (filter === 'me') {
      visibilityFilter = `ci.user_id = $1`;
    } else if (filter === 'friends') {
      visibilityFilter = `
        ci.visibility = 'FRIENDS'
        AND ci.user_id IN (
          SELECT friend_id FROM friendships
          WHERE user_id = $1 AND status = 'ACCEPTED'
        )
        AND (
          ci.audience_type = 'ALL_FRIENDS'
          OR EXISTS (
            SELECT 1 FROM check_in_recipients cir
            WHERE cir.checkin_id = ci.id
              AND cir.recipient_user_id = $1
          )
        )
      `;
    } else {
      // everyone
      visibilityFilter = `
        ci.user_id = $1
        OR (
          ci.visibility = 'FRIENDS'
          AND ci.user_id IN (
            SELECT friend_id FROM friendships
            WHERE user_id = $1 AND status = 'ACCEPTED'
          )
          AND (
            ci.audience_type = 'ALL_FRIENDS'
            OR EXISTS (
              SELECT 1 FROM check_in_recipients cir
              WHERE cir.checkin_id = ci.id
                AND cir.recipient_user_id = $1
            )
          )
        )
      `;
    }

    const sql = `
      SELECT
        ci.id,
        ci.caption,
        ci.rating,
        ci.created_at as "createdAt",
        ci.media_id as "mediaId",
        u.id as "userId",
        u.display_name as "userName",
        u.avatar_url as "userAvatar",
        COALESCE(p.id, pc.id)::text as "placeId",
        COALESCE(p.name, pc.name) as "placeName",
        COALESCE(p.category, pc.category) as category
      FROM check_ins ci
      JOIN users u ON u.id = ci.user_id
      LEFT JOIN places p ON p.id = ci.place_id
      LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
      WHERE (${visibilityFilter})
        ${cursorFilter}
      ORDER BY ci.created_at DESC
      LIMIT $2;
    `;

    const result = await query(sql, params);

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
    console.error('Error fetching check-in feed:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
