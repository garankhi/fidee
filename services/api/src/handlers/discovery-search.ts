import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

type VibeFilter = {
  vibes: string[];
  services?: string[];
  categories?: string[];
};

const VIBE_MAP: Record<string, VibeFilter> = {
  hen_ho: { vibes: ['Dating'] },
  nhom_ban: { vibes: ['Group'] },
  nhom: { vibes: ['Group'] },
  hoc_lam_viec: { vibes: ['Study'] },
  chill: { vibes: ['Chill'] },
  lang_man: { vibes: ['Acoustic', 'Dating'] },
  khong_gian_xanh: { vibes: ['Outdoor'], services: ['Outdoor'] },
  acoustic: { vibes: ['Acoustic'] },
  cafe: { vibes: ['Cafe'], categories: ['cafe'] },
  ngot_ngao: { vibes: ['Cozy', 'Cafe'] },
  dating: { vibes: ['Dating'] },
  group: { vibes: ['Group'] },
  study: { vibes: ['Study'] },
  outdoor: { vibes: ['Outdoor'], services: ['Outdoor'] },
  cozy: { vibes: ['Cozy', 'Cafe'] },
  healthy: { vibes: ['Healthy'] },
};

const CATEGORIES = new Set([
  'cafe',
  'restaurant',
  'hotel',
  'tourist_attraction',
  'office',
  'shopping',
  'other',
]);
const SORT_OPTIONS = new Set(['distance', 'rating', 'popular']);

function json(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

function parseNumber(value: string | undefined): number | null {
  if (value == null || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeSearchText(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd');
}

function resolveVibe(value: string | undefined): VibeFilter | null {
  if (!value?.trim()) return null;
  const trimmed = value.trim();
  return (
    VIBE_MAP[normalizeSearchText(trimmed).replace(/[\s/]+/g, '_')] ?? {
      vibes: [trimmed],
    }
  );
}

/** GET /discovery/search */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    try {
      await extractAuth(event);
    } catch {
      return json(401, { error: 'Unauthorized' });
    }

    const params = event.queryStringParameters ?? {};
    const lat = parseNumber(params.lat);
    const lng = parseNumber(params.lng);
    if (lat == null || lat < -90 || lat > 90 || lng == null || lng < -180 || lng > 180) {
      return json(400, { error: 'Missing or invalid lat/lng' });
    }

    const keyword = params.q?.trim() || null;
    const vibeFilter = resolveVibe(params.vibe);
    const category = params.category?.trim().toLowerCase() || null;
    if (category && !CATEGORIES.has(category)) {
      return json(400, { error: 'Invalid category' });
    }

    const parsedPriceMax = parseNumber(params.priceMax);
    if (params.priceMax && (parsedPriceMax == null || parsedPriceMax < 0)) {
      return json(400, { error: 'Invalid priceMax' });
    }
    const priceMax = parsedPriceMax == null ? null : Math.floor(parsedPriceMax);

    const parsedRadius = parseNumber(params.radius);
    if (params.radius && (parsedRadius == null || parsedRadius <= 0)) {
      return json(400, { error: 'Invalid radius' });
    }
    const radiusSource = parsedRadius;
    const radius =
      radiusSource == null
        ? null
        : Math.min(Math.max(Math.floor(radiusSource), 100), 50000);

    const sortBy = params.sortBy?.trim().toLowerCase() || 'distance';
    if (!SORT_OPTIONS.has(sortBy)) {
      return json(400, { error: 'Invalid sortBy' });
    }

    const parsedLimit = parseNumber(params.limit);
    const limit = Math.min(Math.max(Math.floor(parsedLimit ?? 20), 1), 50);
    const cursor = params.cursor?.trim() || null;
    if (cursor && Number.isNaN(Date.parse(cursor))) {
      return json(400, { error: 'Invalid cursor' });
    }

    const sqlParams: unknown[] = [lng, lat];
    const conditions = ["ps.status = 'APPROVED'", "ps.visibility = 'PUBLIC'"];

    if (radius != null) {
      sqlParams.push(radius);
      conditions.push(`ST_DWithin(p.location, ST_MakePoint($1, $2)::geography, $3)`);
    }

    const addCondition = (condition: (index: number) => string, value: unknown) => {
      sqlParams.push(value);
      conditions.push(condition(sqlParams.length));
    };

    if (keyword) {
      addCondition((index) => `p.normalized_name ILIKE $${index}`, `%${normalizeSearchText(keyword)}%`);
    }
    if (vibeFilter) {
      const vibeConditions: string[] = [];
      if (vibeFilter.vibes.length > 0) {
        sqlParams.push(vibeFilter.vibes);
        vibeConditions.push(
          `COALESCE(p.metadata->'vibes', '[]'::jsonb) ?| $${sqlParams.length}::text[]`,
        );
      }
      if (vibeFilter.services?.length) {
        sqlParams.push(vibeFilter.services);
        vibeConditions.push(
          `COALESCE(p.metadata->'services', '[]'::jsonb) ?| $${sqlParams.length}::text[]`,
        );
      }
      if (vibeFilter.categories?.length) {
        sqlParams.push(vibeFilter.categories);
        vibeConditions.push(`p.category = ANY($${sqlParams.length}::text[])`);
      }
      conditions.push(`(${vibeConditions.join(' OR ')})`);
    }
    if (category) {
      addCondition((index) => `p.category = $${index}`, category);
    }
    if (priceMax != null) {
      addCondition((index) => `p.price_max <= $${index}`, priceMax);
    }
    if (cursor) {
      addCondition((index) => `p.created_at < $${index}::timestamptz`, cursor);
    }

    const orderClause =
      sortBy === 'rating'
        ? 'COALESCE(p.avg_rating, 0) DESC, p.created_at DESC, p.id ASC'
        : sortBy === 'popular'
          ? '"checkinCount" DESC, p.created_at DESC, p.id ASC'
          : '"distanceMeters" ASC, p.created_at DESC, p.id ASC';

    sqlParams.push(limit + 1);
    const sql = `
      SELECT
        p.id AS "placeId",
        p.name,
        p.category,
        p.address,
        p.description,
        COALESCE(p.avg_rating, 0) AS "avgRating",
        COALESCE(p.rating_count, 0) AS "ratingCount",
        (SELECT COUNT(*)::integer FROM check_ins ci WHERE ci.place_id = p.id) AS "checkinCount",
        p.cover_media_id AS "coverMediaId",
        ST_Y(p.location::geometry) AS lat,
        ST_X(p.location::geometry) AS lng,
        ST_Distance(p.location, ST_MakePoint($1, $2)::geography)::integer AS "distanceMeters",
        p.price_min AS "priceMin",
        p.price_max AS "priceMax",
        p.created_at AS "createdAt",
        COALESCE(p.metadata->'vibes', '[]'::jsonb) AS vibes,
        COALESCE(p.metadata->'services', '[]'::jsonb) AS services
      FROM places p
      JOIN place_settings ps ON ps.place_id = p.id
      WHERE ${conditions.join('\n        AND ')}
      ORDER BY ${orderClause}
      LIMIT $${sqlParams.length};
    `;

    const result = await query(sql, sqlParams);
    const hasMore = result.rows.length > limit;
    const data = hasMore ? result.rows.slice(0, limit) : result.rows;
    const lastCreatedAt = data.at(-1)?.createdAt;
    const nextCursor =
      hasMore && lastCreatedAt ? new Date(String(lastCreatedAt)).toISOString() : null;

    return json(200, {
      status: 'success',
      data,
      pagination: { nextCursor, hasMore },
    });
  } catch (error) {
    console.error('Error in discovery search:', error);
    return json(500, { error: 'Internal Server Error' });
  }
}
