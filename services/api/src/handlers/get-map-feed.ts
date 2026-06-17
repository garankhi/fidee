import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

/**
 * GET /map/feed
 * Returns recent check-ins from the user's friends and the user themselves,
 * within a given radius.
 *
 * Query params:
 * - lat: latitude (required)
 * - lng: longitude (required)
 * - radius: radius in meters (optional, default 5000)
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
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const lat = parseFloat(event.queryStringParameters?.lat || '');
    const lng = parseFloat(event.queryStringParameters?.lng || '');
    const radius = parseInt(event.queryStringParameters?.radius || '5000', 10);

    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return { statusCode: 400, body: JSON.stringify({ error: 'Missing or invalid lat/lng' }) };
    }

    const sql = `
      SELECT
        ci.id,
        ci.caption,
        ci.created_at as "createdAt",
        ci.media_id as "mediaId",
        ci.media_type as "mediaType",
        u.id as "userId",
        u.display_name as "userName",
        u.avatar_url as "userAvatar",
        COALESCE(p.id, pc.id)::text as "placeId",
        COALESCE(p.name, pc.name) as "placeName",
        COALESCE(p.category, pc.category) as category,
        COALESCE(ST_Y(p.location::geometry), ST_Y(pc.location::geometry)) AS lat,
        COALESCE(ST_X(p.location::geometry), ST_X(pc.location::geometry)) AS lng
      FROM check_ins ci
      JOIN users u ON u.id = ci.user_id
      LEFT JOIN places p ON p.id = ci.place_id
      LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
      WHERE (
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
        )
        AND COALESCE(p.location, pc.location) IS NOT NULL
        AND (pc.id IS NULL OR pc.visibility = 'FRIENDS' OR pc.created_by = $1)
        AND ST_DWithin(COALESCE(p.location, pc.location), ST_MakePoint($2, $3)::geography, $4)
      ORDER BY ci.created_at DESC
      LIMIT 50;
    `;

    const result = await query(sql, [userId, lng, lat, radius]);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({ data: result.rows }),
    };
  } catch (error) {
    console.error('Error fetching map feed:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
