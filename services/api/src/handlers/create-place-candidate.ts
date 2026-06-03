import { HeadObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth } from '../middleware/auth';
import { ValidationError } from '../media/validation';
import { getUserPlan, UserPlan } from '../repositories/user-profiles';
import {
  buildCandidateId,
  countUserCandidatesToday,
  findNearbyCandidates,
  isPlaceCategory,
  NearbyCandidate,
  PlaceCandidate,
  PlaceCategory,
  putCandidate,
  QUOTA_LIMITS,
} from '../repositories/place-candidates';
import { encodeGeohash, normalizeName } from '../utils/geo';

// ─── Types ──────────────────────────────────────────────────────

interface CandidateRequest {
  name: string;
  category: PlaceCategory;
  mediaId: string;
  coordinates: { lat: number; lng: number };
  force?: boolean;
}

interface CreatePlaceCandidateDeps {
  getPlan: (userId: string) => Promise<UserPlan>;
  putCandidate: (tableName: string, candidate: PlaceCandidate, client?: DynamoDBDocumentClient) => Promise<'created' | 'duplicate'>;
  countToday: (tableName: string, userId: string, dateStr: string, client?: DynamoDBDocumentClient) => Promise<number>;
  findNearby: (tableName: string, lat: number, lng: number, radius: number, normalizedName: string, client?: DynamoDBDocumentClient) => Promise<NearbyCandidate[]>;
  verifyMedia: (bucket: string, mediaId: string) => Promise<{ lat: number; lng: number } | null>;
  candidateIdFactory: () => string;
  env: {
    placesTable: string;
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
  if (typeof mediaId !== 'string' || mediaId.trim().length === 0) {
    throw new ValidationError('mediaId is required');
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
    mediaId: mediaId.trim(),
    coordinates: { lat, lng },
    force: body.force === true,
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
  const placesTable = process.env.PLACES_TABLE;
  if (!placesTable) throw new Error('PLACES_TABLE is required');

  const mediaBucket = process.env.MEDIA_BUCKET;
  if (!mediaBucket) throw new Error('MEDIA_BUCKET is required');

  const userProfilesTable = process.env.USER_PROFILES_TABLE;
  if (!userProfilesTable) throw new Error('USER_PROFILES_TABLE is required');

  return {
    getPlan: (userId) => getUserPlan(userId, userProfilesTable),
    putCandidate,
    countToday: countUserCandidatesToday,
    findNearby: findNearbyCandidates,
    verifyMedia: (bucket, mediaId) => verifyMediaInS3(bucket, mediaId),
    candidateIdFactory: buildCandidateId,
    env: { placesTable, mediaBucket, userProfilesTable },
  };
}

export function createPlaceCandidateHandler(deps: CreatePlaceCandidateDeps) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
      // 1. Auth
      const auth = await extractAuth(event);

      // 2. Parse + validate request
      let parsed: unknown;
      try {
        parsed = JSON.parse(event.body ?? '');
      } catch {
        throw new ValidationError('Request body must be valid JSON');
      }
      const request = validateCandidateRequest(parsed);

      // 3. Verify media exists in S3 with GPS proof
      const mediaGps = await deps.verifyMedia(deps.env.mediaBucket, request.mediaId);
      if (!mediaGps) {
        return jsonResponse(400, {
          status: 'error',
          error: { code: 'INVALID_MEDIA', message: 'Media not found or missing GPS proof' },
        });
      }

      // 4. Check quota
      const plan = await deps.getPlan(auth.sub);
      const today = new Date().toISOString().slice(0, 10);
      const usedToday = await deps.countToday(deps.env.placesTable, auth.sub, today);
      const limit = QUOTA_LIMITS[plan];
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

      // 5. Normalize name + encode geohash
      const normalized = normalizeName(request.name);
      const geohash = encodeGeohash(request.coordinates.lat, request.coordinates.lng, 4);

      // 6. Dedup check (unless force=true)
      if (!request.force) {
        const duplicates = await deps.findNearby(
          deps.env.placesTable,
          request.coordinates.lat,
          request.coordinates.lng,
          100,
          normalized,
        );
        if (duplicates.length > 0) {
          return jsonResponse(409, {
            status: 'conflict',
            error: {
              code: 'NEAR_DUPLICATE',
              message: 'Similar place candidates found nearby',
            },
            candidates: duplicates,
          });
        }
      }

      // 7. Create candidate
      const now = new Date().toISOString();
      const candidate: PlaceCandidate = {
        candidateId: deps.candidateIdFactory(),
        name: request.name,
        normalizedName: normalized,
        category: request.category,
        lat: request.coordinates.lat,
        lng: request.coordinates.lng,
        geohash,
        status: 'PENDING_REVIEW',
        visibility: 'FRIENDS',
        createdBy: auth.sub,
        mediaId: request.mediaId,
        createdAt: now,
        updatedAt: now,
      };

      await deps.putCandidate(deps.env.placesTable, candidate);

      return jsonResponse(201, {
        status: 'created',
        data: {
          candidate_id: candidate.candidateId,
          name: candidate.name,
          normalized_name: candidate.normalizedName,
          category: candidate.category,
          coordinates: { lat: candidate.lat, lng: candidate.lng },
          status: candidate.status,
          visibility: candidate.visibility,
          created_by: candidate.createdBy,
          created_at: candidate.createdAt,
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
