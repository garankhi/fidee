import { HeadObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';
import { ValidationError } from '../media/validation';
import { getUserPlan, UserPlan } from '../repositories/user-profiles';
import { buildCandidateId, isPlaceCategory, PlaceCategory, QUOTA_LIMITS } from '../repositories/place-candidates';
import { normalizeName } from '../utils/geo';

// ─── Types ──────────────────────────────────────────────────────

interface CandidateRequest {
  name: string;
  category: PlaceCategory;
  mediaId?: string;
  coordinates: { lat: number; lng: number };
  force?: boolean;
  address?: string;
  openTime?: string;
  closeTime?: string;
  priceMin?: number;
  priceMax?: number;
  phoneNumber?: string;
  description?: string;
}

interface CreatePlaceCandidateDeps {
  getPlan: (userId: string) => Promise<UserPlan>;
  verifyMedia: (bucket: string, mediaId: string) => Promise<{ lat: number; lng: number } | null>;
  candidateIdFactory: () => string;
  env: {
    mediaBucket: string;
    userProfilesTable: string;
  };
}

// ─── Helpers ────────────────────────────────────────────────────

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify(body),
  };
}

function validateCandidateRequest(value: unknown): CandidateRequest {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new ValidationError('Request body must be a JSON object');
  }

  const body = value as Record<string, unknown>;

  const name = body.name;
  if (typeof name !== 'string' || name.trim().length < 2) {
    throw new ValidationError('name is required and must be at least 2 characters');
  }
  if (name.length > 100) {
    throw new ValidationError('name must not exceed 100 characters');
  }

  const category = body.category;
  if (!isPlaceCategory(category)) {
    throw new ValidationError('category must be one of: cafe, restaurant, hotel, tourist_attraction, office, shopping, other');
  }

  const mediaId = body.mediaId;
  if (mediaId !== undefined && (typeof mediaId !== 'string' || mediaId.trim().length === 0)) {
    throw new ValidationError('mediaId must be a non-empty string when provided');
  }

  const coords = body.coordinates;
  if (typeof coords !== 'object' || coords === null) {
    throw new ValidationError('coordinates is required with lat and lng');
  }
  const { lat, lng } = coords as Record<string, unknown>;
  if (typeof lat !== 'number' || lat < -90 || lat > 90) {
    throw new ValidationError('coordinates.lat must be between -90 and 90');
  }
  if (typeof lng !== 'number' || lng < -180 || lng > 180) {
    throw new ValidationError('coordinates.lng must be between -180 and 180');
  }

  return {
    name: name.trim(),
    category,
    mediaId: typeof mediaId === 'string' ? mediaId.trim() : undefined,
    coordinates: { lat, lng },
    force: body.force === true,
    address: typeof body.address === 'string' ? body.address.trim() : undefined,
    openTime: typeof body.openTime === 'string' ? body.openTime.trim() : undefined,
    closeTime: typeof body.closeTime === 'string' ? body.closeTime.trim() : undefined,
    priceMin: typeof body.priceMin === 'number' ? body.priceMin : undefined,
    priceMax: typeof body.priceMax === 'number' ? body.priceMax : undefined,
    phoneNumber: typeof body.phoneNumber === 'string' ? body.phoneNumber.trim() : undefined,
    description: typeof body.description === 'string' ? body.description.trim() : undefined,
  };
}

// ─── S3 Media Verification ──────────────────────────────────────

const s3Client = new S3Client({});

async function verifyMediaInS3(
  bucket: string,
  mediaId: string,
): Promise<{ lat: number; lng: number } | null> {
  // Try common extensions
  for (const ext of ['jpg', 'png', 'webp']) {
    try {
      const result = await s3Client.send(
        new HeadObjectCommand({
          Bucket: bucket,
          Key: `uploads/${mediaId}.${ext}`,
        }),
      );
      const metadata = result.Metadata ?? {};
      const lat = parseFloat(metadata['gps-latitude'] ?? '');
      const lng = parseFloat(metadata['gps-longitude'] ?? '');
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        return { lat, lng };
      }
      return null;
    } catch {
      continue;
    }
  }
  return null;
}

// ─── Handler ────────────────────────────────────────────────────

function defaultDeps(): CreatePlaceCandidateDeps {
  const mediaBucket = process.env.MEDIA_BUCKET;
  if (!mediaBucket) throw new Error('MEDIA_BUCKET is required');

  const userProfilesTable = process.env.USER_PROFILES_TABLE;
  if (!userProfilesTable) throw new Error('USER_PROFILES_TABLE is required');

  return {
    getPlan: (userId) => getUserPlan(userId, userProfilesTable),
    verifyMedia: (bucket, mediaId) => verifyMediaInS3(bucket, mediaId),
    candidateIdFactory: buildCandidateId,
    env: { mediaBucket, userProfilesTable },
  };
}

export function createPlaceCandidateHandler(deps: CreatePlaceCandidateDeps) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
      // 1. Auth
      const auth = await extractAuth(event);
      const userId = auth.sub;

      // 2. Parse + validate request
      let parsed: unknown;
      try {
        parsed = JSON.parse(event.body ?? '');
      } catch {
        throw new ValidationError('Request body must be valid JSON');
      }
      const request = validateCandidateRequest(parsed);

      // 3. Verify media exists in S3 with GPS proof when a mediaId is supplied.
      if (request.mediaId) {
        const mediaGps = await deps.verifyMedia(deps.env.mediaBucket, request.mediaId);
        if (!mediaGps) {
          return jsonResponse(400, {
            status: 'error',
            error: { code: 'INVALID_MEDIA', message: 'Media not found or missing GPS proof' },
          });
        }
      }

      // 4. Check quota (PostgreSQL)
      const plan = await deps.getPlan(userId);
      const limit = QUOTA_LIMITS[plan];
      const countSql = `
        SELECT COUNT(*) as count 
        FROM place_candidates 
        WHERE created_by = $1 AND DATE(created_at) = CURRENT_DATE;
      `;
      const countRes = await query(countSql, [userId]);
      const usedToday = parseInt(countRes.rows[0].count as string, 10);
      
      if (usedToday >= limit) {
        return jsonResponse(429, {
          status: 'error',
          error: {
            code: 'QUOTA_EXCEEDED',
            message: `Daily limit reached (${limit} candidates/day for ${plan} plan)`,
            daily_limit: limit,
            used: usedToday,
          },
        });
      }

      // 5. Normalize name
      const normalized = normalizeName(request.name);

      // 6. Dedup check (PostgreSQL)
      if (!request.force) {
        const dedupSql = `
          SELECT id, name, normalized_name, ST_Distance(location, ST_MakePoint($1, $2)::geography) AS distance_meters
          FROM place_candidates
          WHERE ST_DWithin(location, ST_MakePoint($1, $2)::geography, 100)
            AND (normalized_name = $3 OR similarity(normalized_name, $3) > 0.3)
          LIMIT 5;
        `;
        const dupRes = await query(dedupSql, [request.coordinates.lng, request.coordinates.lat, normalized]);
        if (dupRes.rows.length > 0) {
          return jsonResponse(409, {
            status: 'conflict',
            error: {
              code: 'NEAR_DUPLICATE',
              message: 'Similar place candidates found nearby',
            },
            candidates: dupRes.rows.map((r: any) => ({
              candidateId: r.id,
              name: r.name,
              normalizedName: r.normalized_name,
              distanceMeters: Math.round(parseFloat(r.distance_meters))
            })),
          });
        }
      }

      // 7. Create candidate in PostgreSQL
      const uuidCandidateId = randomUUID(); // Use standard UUID for Postgres

      const insertSql = `
        INSERT INTO place_candidates (
          id, name, normalized_name, category, location, media_id, 
          status, visibility, created_by,
          address, open_time, close_time, price_min, price_max, phone_number, description
        ) VALUES (
          $1, $2, $3, $4, ST_MakePoint($5, $6)::geography, $7, 
          'PENDING_REVIEW', 'FRIENDS', $8,
          $9, $10, $11, $12, $13, $14, $15
        ) RETURNING created_at;
      `;
      
      const insertRes = await query(insertSql, [
        uuidCandidateId,
        request.name,
        normalized,
        request.category,
        request.coordinates.lng,
        request.coordinates.lat,
        request.mediaId ?? null,
        userId,
        request.address || null,
        request.openTime || null,
        request.closeTime || null,
        request.priceMin || null,
        request.priceMax || null,
        request.phoneNumber || null,
        request.description || null
      ]);

      return jsonResponse(201, {
        status: 'created',
        data: {
          candidate_id: uuidCandidateId,
          name: request.name,
          normalized_name: normalized,
          category: request.category,
          coordinates: { lat: request.coordinates.lat, lng: request.coordinates.lng },
          status: 'PENDING_REVIEW',
          visibility: 'FRIENDS',
          created_by: userId,
          created_at: insertRes.rows[0].created_at,
          address: request.address,
          open_time: request.openTime,
          close_time: request.closeTime,
          price_min: request.priceMin,
          price_max: request.priceMax,
          phone_number: request.phoneNumber,
          description: request.description,
        },
      });
    } catch (error) {
      if (error instanceof ValidationError) {
        return jsonResponse(400, { status: 'error', error: { code: 'VALIDATION_ERROR', message: error.message } });
      }
      if (error instanceof Error && error.message.startsWith('Missing auth context')) {
        return jsonResponse(401, { status: 'error', error: { code: 'UNAUTHORIZED', message: error.message } });
      }
      if (error instanceof Error && error.message.startsWith('Forbidden')) {
        return jsonResponse(403, { status: 'error', error: { code: 'FORBIDDEN', message: error.message } });
      }
      console.error('Failed to create place candidate', error);
      return jsonResponse(500, { status: 'error', error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } });
    }
  };
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> =>
  createPlaceCandidateHandler(defaultDeps())(event);


