import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /map/heatmap
 * Returns aggregated check-in points for heat map rendering.
 * Each point = a unique place/candidate location + weight (number of check-ins).
 *
 * Query params:
 * - lat: center latitude (required)
 * - lng: center longitude (required)
 * - radius: radius in meters (optional, default 5000, max 50000)
 *
 * Response:
 * {
 *   data: [
 *     { lat, lng, weight, placeId, placeName, category, isCandidate }
 *   ]
 * }
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    let userId: string;
    try {
      const auth = await extractAuth(event);
      userId = auth.sub;
    } catch {
      return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
    }

    const lat = parseFloat(event.queryStringParameters?.lat || '');
    const lng = parseFloat(event.queryStringParameters?.lng || '');
    const radiusRaw = parseInt(event.queryStringParameters?.radius || '5000', 10);
    const radius = Math.min(Math.max(radiusRaw, 100), 50000);

    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Missing or invalid lat/lng' }) };
    }

    // Aggregate check-ins by location (place or candidate).
    // Visibility rules:
    //   - Always show user's own check-ins (any visibility)
    //   - Show friends' check-ins only if visibility = 'FRIENDS'
    const sql = `
      WITH visible_checkins AS (
        SELECT
          ci.id,
          ci.place_id,
          ci.candidate_id,
          ci.user_id
        FROM check_ins ci
        WHERE (
            ci.user_id = $1
            OR (
              ci.visibility = 'FRIENDS'
              AND ci.user_id IN (
                SELECT friend_id FROM friendships
                WHERE user_id = $1 AND status = 'ACCEPTED'
              )
            )
          )
      )
      SELECT
        COALESCE(p.id, pc.id)::text AS "placeId",
        COALESCE(p.name, pc.name) AS "placeName",
        COALESCE(p.category, pc.category) AS category,
        COALESCE(
          ST_Y(p.location::geometry),
          ST_Y(pc.location::geometry)
        ) AS lat,
        COALESCE(
          ST_X(p.location::geometry),
          ST_X(pc.location::geometry)
        ) AS lng,
        COUNT(vc.id)::integer AS weight,
        CASE WHEN vc.candidate_id IS NOT NULL THEN true ELSE false END AS "isCandidate"
      FROM visible_checkins vc
      LEFT JOIN places p ON p.id = vc.place_id
      LEFT JOIN place_candidates pc ON pc.id = vc.candidate_id
      WHERE COALESCE(p.location, pc.location) IS NOT NULL
        AND ST_DWithin(
          COALESCE(p.location, pc.location),
          ST_MakePoint($2, $3)::geography,
          $4
        )
      GROUP BY
        COALESCE(p.id, pc.id),
        COALESCE(p.name, pc.name),
        COALESCE(p.category, pc.category),
        COALESCE(ST_Y(p.location::geometry), ST_Y(pc.location::geometry)),
        COALESCE(ST_X(p.location::geometry), ST_X(pc.location::geometry)),
        CASE WHEN vc.candidate_id IS NOT NULL THEN true ELSE false END
      ORDER BY weight DESC
      LIMIT 200;
    `;

    const result = await query(sql, [userId, lng, lat, radius]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ data: result.rows }),
    };
  } catch (error) {
    console.error('Error fetching heatmap:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
