import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /admin/places/candidates/{id}
 *
 * Returns detailed info about a pending candidate for admin review:
 * - Candidate data (name, category, location, metadata, media)
 * - Creator info
 * - GPS proof from related check-ins
 * - Duplicate hints: approved places within 100m with similar names
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const userId =
      event.requestContext.authorizer?.jwt?.claims?.sub ||
      event.requestContext.authorizer?.claims?.sub;
    if (!userId) {
      return {
        statusCode: 401,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const candidateId = event.pathParameters?.id;
    if (!candidateId) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Missing candidate id' }),
      };
    }

    // 1. Get candidate detail with creator info
    const candidateSql = `
      SELECT
        pc.id,
        pc.name,
        pc.normalized_name,
        pc.category,
        pc.media_id,
        pc.created_by,
        pc.created_at,
        pc.open_time,
        pc.close_time,
        pc.price_min,
        pc.price_max,
        pc.phone_number,
        pc.description,
        ST_Y(pc.location::geometry) AS lat,
        ST_X(pc.location::geometry) AS lng,
        u.display_name AS created_by_name,
        u.username AS created_by_username,
        u.avatar_url AS created_by_avatar
      FROM place_candidates pc
      JOIN users u ON pc.created_by = u.id
      WHERE pc.id = $1;
    `;
    const candidateResult = await query(candidateSql, [candidateId]);

    if (candidateResult.rows.length === 0) {
      return {
        statusCode: 404,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Candidate not found' }),
      };
    }

    const candidate = candidateResult.rows[0];

    // 2. GPS proof: find check-ins near the candidate's location by the creator
    const gpsSql = `
      SELECT
        ci.gps_lat,
        ci.gps_lng,
        ci.gps_accuracy,
        ci.media_id,
        ci.created_at
      FROM check_ins ci
      WHERE ci.user_id = $1
        AND ST_DWithin(
          ST_MakePoint(ci.gps_lng, ci.gps_lat)::geography,
          ST_MakePoint($2, $3)::geography,
          200
        )
      ORDER BY ci.created_at DESC
      LIMIT 5;
    `;
    const gpsResult = await query(gpsSql, [candidate.created_by, candidate.lng, candidate.lat]);

    // 3. Duplicate hints: approved places within 100m
    const duplicateSql = `
      SELECT
        p.id,
        p.name,
        p.category,
        p.address,
        ST_Distance(p.location, ST_MakePoint($1, $2)::geography) AS distance_meters
      FROM places p
      JOIN place_settings ps ON ps.place_id = p.id
      WHERE ST_DWithin(p.location, ST_MakePoint($1, $2)::geography, 100)
        AND ps.status = 'APPROVED'
      ORDER BY distance_meters ASC
      LIMIT 10;
    `;
    const duplicateResult = await query(duplicateSql, [candidate.lng, candidate.lat]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          candidate: {
            ...candidate,
            coordinates: {
              lat: parseFloat(String(candidate.lat)),
              lng: parseFloat(String(candidate.lng)),
            },
          },
          gps_proof: gpsResult.rows,
          duplicate_hints: duplicateResult.rows.map((r: any) => ({
            ...r,
            distance_meters: Math.round(parseFloat(r.distance_meters)),
          })),
        },
      }),
    };
  } catch (error) {
    console.error('Error getting candidate detail:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
