import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /admin/places/pending
 *
 * Lists all place candidates with status = PENDING_REVIEW or NEEDS_MORE_INFO.
 * Returns full place-level detail for each candidate.
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

    const statusFilter = event.queryStringParameters?.status || 'PENDING_REVIEW';

    const sql = `
      SELECT
        pc.id,
        pc.name,
        pc.normalized_name,
        pc.category,
        pc.address,
        ST_Y(pc.location::geometry) AS lat,
        ST_X(pc.location::geometry) AS lng,
        pc.media_id,
        pc.open_time,
        pc.close_time,
        pc.price_min,
        pc.price_max,
        pc.phone_number,
        pc.description,
        pc.metadata,
        pc.status,
        pc.rejection_reason,
        pc.reviewed_by,
        pc.reviewed_at,
        pc.created_at,
        pc.created_by,
        u.display_name AS created_by_name,
        u.username AS created_by_username,
        u.avatar_url AS created_by_avatar
      FROM place_candidates pc
      JOIN users u ON pc.created_by = u.id
      WHERE pc.status = $1
      ORDER BY pc.created_at DESC
      LIMIT 50;
    `;
    const result = await query(sql, [statusFilter]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: result.rows.map((r: any) => ({
          ...r,
          coordinates: { lat: parseFloat(r.lat), lng: parseFloat(r.lng) },
        })),
      }),
    };
  } catch (error) {
    console.error('Error listing pending places:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
