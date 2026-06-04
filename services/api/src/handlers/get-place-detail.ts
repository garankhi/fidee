import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    await extractAuth(event);

    const placeId = event.pathParameters?.id;
    if (!placeId) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Missing place id' }) };
    }

    const placeSql = `
      SELECT
        p.id,
        p.name,
        p.category,
        p.address,
        ST_Y(p.location::geometry) as lat,
        ST_X(p.location::geometry) as lng,
        p.open_time,
        p.close_time,
        p.price_min,
        p.price_max,
        p.description,
        p.metadata,
        ps.visibility,
        ps.status,
        ps.is_featured,
        ps.is_verified,
        (SELECT COUNT(*) FROM check_ins c WHERE c.place_id = p.id) as checkin_count
      FROM places p
      LEFT JOIN place_settings ps ON p.id = ps.place_id
      WHERE p.id = $1 AND (ps.status = 'APPROVED' OR ps.status IS NULL)
    `;
    const placeResult = await query(placeSql, [placeId]);

    if (placeResult.rows.length === 0) {
      const candidateSql = `
        SELECT
          pc.id,
          pc.name,
          pc.category,
          pc.address,
          ST_Y(pc.location::geometry) as lat,
          ST_X(pc.location::geometry) as lng,
          pc.metadata,
          pc.status,
          (SELECT COUNT(*) FROM check_ins c WHERE c.candidate_id = pc.id) as checkin_count
        FROM place_candidates pc
        WHERE pc.id = $1
      `;
      const candidateResult = await query(candidateSql, [placeId]);
      if (candidateResult.rows.length === 0) {
        return { statusCode: 404, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Place not found' }) };
      }

      const candidate = candidateResult.rows[0];
      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify({
          status: 'success',
          data: {
            ...candidate,
            coordinates: { lat: parseFloat(String(candidate.lat)), lng: parseFloat(String(candidate.lng)) },
          },
        }),
      };
    }

    const place = placeResult.rows[0];
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          ...place,
          coordinates: { lat: parseFloat(String(place.lat)), lng: parseFloat(String(place.lng)) },
        },
      }),
    };
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Missing auth context')) {
      return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
    }
    console.error('Failed to get place detail:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
