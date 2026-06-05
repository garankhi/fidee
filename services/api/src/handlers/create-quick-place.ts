import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';
import { normalizeName } from '../utils/geo';
import { isPlaceCategory, PlaceCategory, QUOTA_LIMITS } from '../repositories/place-candidates';
import { getUserPlan } from '../repositories/user-profiles';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

function json(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

/**
 * POST /place-candidates/quick
 *
 * Lightweight endpoint to create a place candidate with minimal info.
 * Only name + coordinates are required. Category is optional (defaults to 'other').
 *
 * Body: { name, lat, lng, category? }
 * Returns: created candidate with id, ready to be used in check-in.
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    // 1. Auth
    let userId: string;
    try {
      const auth = await extractAuth(event);
      userId = auth.sub;
    } catch {
      return json(401, { error: 'Unauthorized' });
    }

    // 2. Parse body
    let body: Record<string, unknown>;
    try {
      body = JSON.parse(event.body ?? '{}');
    } catch {
      return json(400, { error: 'Invalid JSON body' });
    }

    // 3. Validate
    const { name, lat, lng, category } = body as {
      name?: string;
      lat?: number;
      lng?: number;
      category?: string;
    };

    if (!name || typeof name !== 'string' || name.trim().length < 2) {
      return json(400, { error: 'name is required (min 2 characters)' });
    }
    if (name.length > 100) {
      return json(400, { error: 'name must not exceed 100 characters' });
    }
    if (typeof lat !== 'number' || lat < -90 || lat > 90) {
      return json(400, { error: 'lat is required and must be between -90 and 90' });
    }
    if (typeof lng !== 'number' || lng < -180 || lng > 180) {
      return json(400, { error: 'lng is required and must be between -180 and 180' });
    }

    const resolvedCategory: PlaceCategory = (category && isPlaceCategory(category)) ? category : 'other';
    const trimmedName = name.trim();
    const normalized = normalizeName(trimmedName);

    // 4. Quota check
    const userProfilesTable = process.env.USER_PROFILES_TABLE || '';
    const plan = await getUserPlan(userId, userProfilesTable);
    const limit = QUOTA_LIMITS[plan];

    const countRes = await query(
      `SELECT COUNT(*) as count FROM place_candidates WHERE created_by = $1 AND DATE(created_at) = CURRENT_DATE`,
      [userId],
    );
    const usedToday = parseInt(countRes.rows[0].count as string, 10);

    if (usedToday >= limit) {
      return json(429, {
        error: 'QUOTA_EXCEEDED',
        message: `Daily limit reached (${limit}/day for ${plan} plan)`,
        daily_limit: limit,
        used: usedToday,
      });
    }

    // 5. Dedup check (same name within 100m)
    const dedupRes = await query(
      `SELECT id, name, ST_Distance(location, ST_MakePoint($1, $2)::geography) AS distance_meters
       FROM place_candidates
       WHERE ST_DWithin(location, ST_MakePoint($1, $2)::geography, 100)
         AND (normalized_name = $3 OR similarity(normalized_name, $3) > 0.3)
       LIMIT 5`,
      [lng, lat, normalized],
    );

    if (dedupRes.rows.length > 0) {
      return json(409, {
        error: 'NEAR_DUPLICATE',
        message: 'Similar place candidates found nearby. Use one of these or set force=true.',
        candidates: dedupRes.rows.map((r: any) => ({
          candidateId: r.id,
          name: r.name,
          distanceMeters: Math.round(parseFloat(r.distance_meters)),
        })),
      });
    }

    // 6. Insert
    const candidateId = randomUUID();

    const insertRes = await query(
      `INSERT INTO place_candidates (id, name, normalized_name, category, location, status, visibility, created_by)
       VALUES ($1, $2, $3, $4, ST_MakePoint($5, $6)::geography, 'PENDING_REVIEW', 'FRIENDS', $7)
       RETURNING created_at`,
      [candidateId, trimmedName, normalized, resolvedCategory, lng, lat, userId],
    );

    return json(201, {
      status: 'created',
      data: {
        candidateId,
        name: trimmedName,
        category: resolvedCategory,
        lat,
        lng,
        status: 'PENDING_REVIEW',
        createdAt: insertRes.rows[0].created_at,
      },
    });
  } catch (error) {
    console.error('Failed to create quick place candidate:', error);
    return json(500, { error: 'Internal Server Error' });
  }
}
