import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';
import { CORS_HEADERS, getAdminId, isAuthResponse } from './places-common';

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const adminId = await getAdminId(event);
    if (isAuthResponse(adminId)) return adminId;

    const status = event.queryStringParameters?.status || null;
    const q = event.queryStringParameters?.q?.trim() || null;
    const searchPattern = q ? `%${q}%` : null;

    const result = await query(
      `
        SELECT
          p.id,
          p.name,
          p.normalized_name,
          p.category,
          p.address,
          ST_Y(p.location::geometry) AS lat,
          ST_X(p.location::geometry) AS lng,
          p.open_time,
          p.close_time,
          p.price_min,
          p.price_max,
          p.phone_number,
          p.description,
          p.metadata,
          p.avg_rating,
          p.rating_count,
          p.checkin_count,
          p.cover_media_id,
          p.created_at,
          p.created_by,
          u.display_name AS created_by_name,
          u.username AS created_by_username,
          COALESCE(ps.visibility, 'PUBLIC') AS visibility,
          COALESCE(ps.status, 'APPROVED') AS status,
          ps.is_featured,
          ps.is_verified,
          ps.updated_at
        FROM places p
        LEFT JOIN users u ON u.id = p.created_by
        LEFT JOIN place_settings ps ON ps.place_id = p.id
        WHERE COALESCE(ps.status, 'APPROVED') != 'DELETED'
          AND ($1::text IS NULL OR ps.status = $1)
          AND ($2::text IS NULL OR p.name ILIKE $2 OR p.address ILIKE $2)
        ORDER BY p.created_at DESC
        LIMIT 100;
      `,
      [status, searchPattern],
    );

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: result.rows.map((row: any) => ({
          ...row,
          coordinates: {
            lat: parseFloat(String(row.lat)),
            lng: parseFloat(String(row.lng)),
          },
        })),
      }),
    };
  } catch (error) {
    console.error('Error listing admin places:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
