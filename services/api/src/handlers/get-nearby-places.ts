import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

const DEFAULT_RADIUS = 100;
const MAX_RADIUS = 300;

type Confidence = 'high' | 'medium' | 'low';

function getConfidence(distanceMeters: number): Confidence {
  if (distanceMeters < 15) return 'high';
  if (distanceMeters < 50) return 'medium';
  return 'low';
}

/**
 * GET /places/nearby
 *
 * Returns nearby places for the post-capture check-in flow.
 * Queries PostgreSQL (PostGIS) for:
 *   1. Public approved places within radius
 *   2. Friends' place_candidates within radius
 *
 * Phase C (MVP): DB-only, no Goong fallback.
 *
 * Query params:
 *   - lat (required): GPS latitude
 *   - lng (required): GPS longitude
 *   - radius (optional): search radius in meters (default 100, max 300)
 *   - context (optional): e.g. 'camera_check_in'
 *   - media_id (optional): associated media ID
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    // 1. Auth
    const userId = event.requestContext.authorizer?.jwt?.claims?.sub
      || event.requestContext.authorizer?.claims?.sub;
    if (!userId) {
      return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
    }

    // 2. Parse & validate params
    const lat = parseFloat(event.queryStringParameters?.lat || '');
    const lng = parseFloat(event.queryStringParameters?.lng || '');
    if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Missing or invalid lat/lng' }),
      };
    }

    let radius = parseInt(event.queryStringParameters?.radius || `${DEFAULT_RADIUS}`, 10);
    if (isNaN(radius) || radius <= 0) radius = DEFAULT_RADIUS;
    if (radius > MAX_RADIUS) radius = MAX_RADIUS;

    // 3. Query public approved places within radius
    const publicPlacesSql = `
      SELECT
        p.id,
        p.name AS display_name,
        p.category,
        p.address,
        p.source,
        p.goong_place_id AS place_id,
        p.open_time,
        p.close_time,
        p.price_min,
        p.price_max,
        p.metadata,
        ST_Y(p.location::geometry) AS lat,
        ST_X(p.location::geometry) AS lng,
        ST_Distance(p.location, ST_MakePoint($1, $2)::geography) AS distance_meters
      FROM places p
      JOIN place_settings ps ON ps.place_id = p.id
      WHERE ST_DWithin(p.location, ST_MakePoint($1, $2)::geography, $3)
        AND ps.status = 'APPROVED'
        AND ps.visibility IN ('PUBLIC', 'FRIENDS')
      ORDER BY distance_meters ASC
      LIMIT 20;
    `;
    const publicResult = await query(publicPlacesSql, [lng, lat, radius]);

    // 4. Query friends' place_candidates within radius
    const friendCandidatesSql = `
      SELECT
        pc.id,
        pc.name AS display_name,
        pc.category,
        'custom' AS source,
        NULL AS place_id,
        NULL AS address,
        pc.open_time,
        pc.close_time,
        pc.price_min,
        pc.price_max,
        pc.created_by,
        ST_Y(pc.location::geometry) AS lat,
        ST_X(pc.location::geometry) AS lng,
        ST_Distance(pc.location, ST_MakePoint($1, $2)::geography) AS distance_meters
      FROM place_candidates pc
      WHERE ST_DWithin(pc.location, ST_MakePoint($1, $2)::geography, $3)
        AND pc.created_by IN (
          SELECT friend_id FROM friendships
          WHERE user_id = $4 AND status = 'ACCEPTED'
        )
      ORDER BY distance_meters ASC
      LIMIT 10;
    `;
    const friendResult = await query(friendCandidatesSql, [lng, lat, radius, userId]);

    // 5. Merge, deduplicate by name similarity, sort by distance
    const allResults = [
      ...publicResult.rows.map((r: any) => ({
        id: r.id,
        place_id: r.place_id || null,
        source: r.source || 'custom',
        display_name: r.display_name,
        address: r.address || null,
        category: r.category,
        distance_meters: Math.round(parseFloat(r.distance_meters)),
        confidence: getConfidence(parseFloat(r.distance_meters)),
        coordinates: { lat: parseFloat(r.lat), lng: parseFloat(r.lng) },
        open_time: r.open_time || null,
        close_time: r.close_time || null,
        price_min: r.price_min || null,
        price_max: r.price_max || null,
        metadata: r.metadata || {},
      })),
      ...friendResult.rows.map((r: any) => ({
        id: r.id,
        place_id: null,
        source: 'friend_candidate',
        display_name: r.display_name,
        address: null,
        category: r.category,
        distance_meters: Math.round(parseFloat(r.distance_meters)),
        confidence: getConfidence(parseFloat(r.distance_meters)),
        coordinates: { lat: parseFloat(r.lat), lng: parseFloat(r.lng) },
        open_time: r.open_time || null,
        close_time: r.close_time || null,
        price_min: r.price_min || null,
        price_max: r.price_max || null,
      })),
    ];

    // Sort all by distance
    allResults.sort((a, b) => a.distance_meters - b.distance_meters);

    // 6. Always append custom fallback entry at end
    allResults.push({
      id: 'custom_fallback',
      place_id: null,
      source: 'custom',
      display_name: 'Tạo địa điểm mới tại đây',
      address: null,
      category: 'other',
      distance_meters: 0,
      confidence: 'low' as Confidence,
      coordinates: { lat, lng },
      open_time: null,
      close_time: null,
      price_min: null,
      price_max: null,
      actions: { primary: 'create_custom_place' },
    } as any);

    // 7. Build response
    const response = {
      status: 'success',
      metadata: {
        source: 'local_db',
        has_goong_fallback: false,
        total_results: allResults.length,
        request_lat: lat,
        request_lng: lng,
        radius_meters: radius,
      },
      data: allResults,
    };

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in get-nearby-places:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
