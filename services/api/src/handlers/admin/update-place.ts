import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';
import { normalizeName } from '../../utils/geo';
import {
  AdminPlaceValidationError,
  fetchAdminPlace,
  getAdminId,
  isAuthResponse,
  jsonResponse,
  parsePlaceRequest,
} from './places-common';

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const adminId = await getAdminId(event);
    if (isAuthResponse(adminId)) return adminId;

    const placeId = event.pathParameters?.id;
    if (!placeId) {
      return jsonResponse(400, { error: 'Missing place id' });
    }

    const request = parsePlaceRequest(event.body);
    const existing = await fetchAdminPlace(placeId);
    if (!existing) {
      return jsonResponse(404, { error: 'Place not found' });
    }

    await query(
      `
        UPDATE places
        SET
          name = $1,
          normalized_name = $2,
          category = $3,
          address = $4,
          location = ST_MakePoint($5, $6)::geography,
          open_time = $7,
          close_time = $8,
          price_min = $9,
          price_max = $10,
          phone_number = $11,
          description = $12
        WHERE id = $13;
      `,
      [
        request.name,
        normalizeName(request.name),
        request.category,
        request.address || null,
        request.coordinates.lng,
        request.coordinates.lat,
        request.openTime || null,
        request.closeTime || null,
        request.priceMin ?? null,
        request.priceMax ?? null,
        request.phoneNumber || null,
        request.description || null,
        placeId,
      ],
    );

    await query(
      `
        INSERT INTO place_settings (place_id, visibility, status, updated_by)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (place_id) DO UPDATE
        SET visibility = EXCLUDED.visibility,
            status = EXCLUDED.status,
            updated_by = EXCLUDED.updated_by;
      `,
      [placeId, request.visibility || 'PUBLIC', request.status || 'APPROVED', adminId],
    );

    await query(
      `
        INSERT INTO place_moderation (place_id, action, performed_by, note, previous_status, new_status)
        VALUES ($1, 'VISIBILITY_CHANGED', $2, 'Updated from admin dashboard', $3, $4);
      `,
      [placeId, adminId, existing.status || null, request.status || 'APPROVED'],
    );

    return jsonResponse(200, { status: 'success', data: await fetchAdminPlace(placeId) });
  } catch (error) {
    if (error instanceof AdminPlaceValidationError) {
      return jsonResponse(400, { error: error.message });
    }
    console.error('Error updating admin place:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
