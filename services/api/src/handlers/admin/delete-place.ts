import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';
import { fetchAdminPlace, getAdminId, isAuthResponse, jsonResponse } from './places-common';

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const adminId = await getAdminId(event);
    if (isAuthResponse(adminId)) return adminId;

    const placeId = event.pathParameters?.id;
    if (!placeId) {
      return jsonResponse(400, { error: 'Missing place id' });
    }

    const existing = await fetchAdminPlace(placeId);
    if (!existing) {
      return jsonResponse(404, { error: 'Place not found' });
    }

    await query(
      `
        INSERT INTO place_settings (place_id, visibility, status, updated_by)
        VALUES ($1, 'PRIVATE', 'DELETED', $2)
        ON CONFLICT (place_id) DO UPDATE
        SET visibility = 'PRIVATE',
            status = 'DELETED',
            updated_by = EXCLUDED.updated_by;
      `,
      [placeId, adminId],
    );

    await query(
      `
        INSERT INTO place_moderation (place_id, action, performed_by, note, previous_status, new_status)
        VALUES ($1, 'HIDDEN', $2, 'Soft deleted from admin dashboard', $3, 'DELETED');
      `,
      [placeId, adminId, existing.status || null],
    );

    return jsonResponse(200, {
      status: 'success',
      data: {
        id: placeId,
        status: 'DELETED',
      },
    });
  } catch (error) {
    console.error('Error deleting admin place:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
