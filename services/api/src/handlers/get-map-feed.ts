import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';

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
    // 1. Get user ID from authorizer
    const userId = event.requestContext.authorizer?.jwt?.claims?.sub;
    if (!userId) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };
    }

    // 2. Parse query parameters
    const lat = parseFloat(event.queryStringParameters?.lat || '');
    const lng = parseFloat(event.queryStringParameters?.lng || '');
    const radius = parseInt(event.queryStringParameters?.radius || '5000', 10);

    if (isNaN(lat) || isNaN(lng)) {
      return { statusCode: 400, body: JSON.stringify({ error: 'Missing or invalid lat/lng' }) };
    }

    // 3. Query PostgreSQL for friend check-ins
    // We use PostGIS ST_DWithin for spatial filtering
    const sql = `
      SELECT ci.id, ci.caption, ci.created_at as "createdAt", ci.media_id as "mediaId",
             u.id as "userId", u.display_name as "userName", u.avatar_url as "userAvatar",
             p.id as "placeId", p.name as "placeName", p.category,
             ST_Y(p.location::geometry) AS lat,
             ST_X(p.location::geometry) AS lng
      FROM check_ins ci
      JOIN users u ON u.id = ci.user_id
      JOIN places p ON p.id = ci.place_id
      WHERE ci.user_id IN (
          SELECT friend_id FROM friendships 
          WHERE user_id = $1 AND status = 'ACCEPTED'
          UNION ALL SELECT $1
        )
        AND ST_DWithin(p.location, ST_MakePoint($2, $3)::geography, $4)
        AND ci.visibility IN ('PUBLIC', 'FRIENDS')
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
      body: JSON.stringify({
        data: result.rows
      }),
    };
  } catch (error) {
    console.error('Error fetching map feed:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
