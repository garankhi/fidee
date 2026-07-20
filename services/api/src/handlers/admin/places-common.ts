import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';
import { isPlaceCategory } from '../../repositories/place-candidates';
import { normalizeName } from '../../utils/geo';
import { isAuthResponse, requireAdminFromEvent } from './auth';

export const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

export type AdminPlaceStatus = 'PENDING_REVIEW' | 'APPROVED' | 'HIDDEN' | 'DELETED';
export type AdminPlaceVisibility = 'PUBLIC' | 'FRIENDS' | 'PRIVATE';

export interface AdminPlaceRequest {
  name: string;
  category: string;
  address?: string;
  coordinates: {
    lat: number;
    lng: number;
  };
  visibility?: AdminPlaceVisibility;
  status?: AdminPlaceStatus;
  openTime?: string;
  closeTime?: string;
  priceMin?: number | null;
  priceMax?: number | null;
  phoneNumber?: string;
  description?: string;
}

export class AdminPlaceValidationError extends Error {}

export function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify(body),
  };
}

export async function getAdminId(
  event: APIGatewayProxyEvent,
): Promise<string | APIGatewayProxyResult> {
  return requireAdminFromEvent(event);
}

export { isAuthResponse };

function readOptionalString(body: Record<string, unknown>, key: string): string | undefined {
  const value = body[key];
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

function readOptionalNumber(body: Record<string, unknown>, key: string): number | null | undefined {
  const value = body[key];
  if (value === null) return null;
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function readVisibility(value: unknown): AdminPlaceVisibility {
  if (value === 'PUBLIC' || value === 'FRIENDS' || value === 'PRIVATE') return value;
  return 'PUBLIC';
}

function readStatus(value: unknown): AdminPlaceStatus {
  if (value === 'PENDING_REVIEW' || value === 'APPROVED' || value === 'HIDDEN' || value === 'DELETED') {
    return value;
  }
  return 'APPROVED';
}

export function parsePlaceRequest(bodyText: string | null): AdminPlaceRequest {
  let parsed: unknown;
  try {
    parsed = JSON.parse(bodyText || '{}');
  } catch {
    throw new AdminPlaceValidationError('Request body must be valid JSON');
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new AdminPlaceValidationError('Request body must be a JSON object');
  }

  const body = parsed as Record<string, unknown>;
  const name = readOptionalString(body, 'name');
  if (!name || name.length < 2 || name.length > 100) {
    throw new AdminPlaceValidationError('name is required and must be 2-100 characters');
  }

  const category = body.category;
  if (!isPlaceCategory(category)) {
    throw new AdminPlaceValidationError('category is invalid');
  }

  const coordinates = body.coordinates;
  if (typeof coordinates !== 'object' || coordinates === null) {
    throw new AdminPlaceValidationError('coordinates is required');
  }

  const lat = (coordinates as Record<string, unknown>).lat;
  const lng = (coordinates as Record<string, unknown>).lng;
  if (typeof lat !== 'number' || lat < -90 || lat > 90) {
    throw new AdminPlaceValidationError('coordinates.lat must be between -90 and 90');
  }
  if (typeof lng !== 'number' || lng < -180 || lng > 180) {
    throw new AdminPlaceValidationError('coordinates.lng must be between -180 and 180');
  }

  return {
    name,
    category,
    address: readOptionalString(body, 'address'),
    coordinates: { lat, lng },
    visibility: readVisibility(body.visibility),
    status: readStatus(body.status),
    openTime: readOptionalString(body, 'openTime'),
    closeTime: readOptionalString(body, 'closeTime'),
    priceMin: readOptionalNumber(body, 'priceMin'),
    priceMax: readOptionalNumber(body, 'priceMax'),
    phoneNumber: readOptionalString(body, 'phoneNumber'),
    description: readOptionalString(body, 'description'),
  };
}

export async function fetchAdminPlace(placeId: string): Promise<Record<string, unknown> | null> {
  const sql = `
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
      ps.visibility,
      ps.status,
      ps.is_featured,
      ps.is_verified,
      ps.updated_at
    FROM places p
    LEFT JOIN users u ON u.id = p.created_by
    LEFT JOIN place_settings ps ON ps.place_id = p.id
    WHERE p.id = $1;
  `;
  const result = await query(sql, [placeId]);
  const row = result.rows[0];
  if (!row) return null;

  return {
    ...row,
    coordinates: {
      lat: parseFloat(String(row.lat)),
      lng: parseFloat(String(row.lng)),
    },
  };
}

export async function insertAdminPlace(request: AdminPlaceRequest, adminId: string) {
  const result = await query(
    `
      INSERT INTO places (
        name, normalized_name, category, address, location, source, created_by,
        open_time, close_time, price_min, price_max, phone_number, description, metadata
      )
      VALUES ($1, $2, $3, $4, ST_MakePoint($5, $6)::geography, 'custom', $7, $8, $9, $10, $11, $12, $13, '{}')
      RETURNING id;
    `,
    [
      request.name,
      normalizeName(request.name),
      request.category,
      request.address || null,
      request.coordinates.lng,
      request.coordinates.lat,
      adminId,
      request.openTime || null,
      request.closeTime || null,
      request.priceMin ?? null,
      request.priceMax ?? null,
      request.phoneNumber || null,
      request.description || null,
    ],
  );
  const placeId = result.rows[0].id as string;

  await query(
    `
      INSERT INTO place_settings (place_id, visibility, status, updated_by)
      VALUES ($1, $2, $3, $4);
    `,
    [placeId, request.visibility || 'PUBLIC', request.status || 'APPROVED', adminId],
  );

  await query(
    `
      INSERT INTO place_moderation (place_id, action, performed_by, note, new_status)
      VALUES ($1, 'APPROVED', $2, 'Created from admin dashboard', $3);
    `,
    [placeId, adminId, request.status || 'APPROVED'],
  );

  return fetchAdminPlace(placeId);
}
