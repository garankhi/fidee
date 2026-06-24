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
const SORT_OPTIONS = new Set([
  'distance',
  'rating',
  'popular',
  'price_asc',
  'price_desc',
  'newest',
]);

type NumericRange = {
  min: number | null;
  max: number | null;
};

function json(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

function parseNumber(value: string | undefined): number | null {
  if (value == null || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseList(value: string | undefined): string[] {
  if (!value?.trim()) return [];
  return [...new Set(value.split(',').map((item) => item.trim()).filter(Boolean))];
}

function parseRanges(value: string | undefined): NumericRange[] | null {
  const items = parseList(value);
  if (items.length === 0) return [];

  const ranges: NumericRange[] = [];
  for (const item of items) {
    const match = /^(\d+|\*)-(\d+|\*)$/.exec(item);
    if (!match) return null;
    const min = match[1] === '*' ? null : Number(match[1]);
    const max = match[2] === '*' ? null : Number(match[2]);
    if ((min == null && max == null) || (min != null && max != null && min > max)) {
      return null;
    }
    ranges.push({ min, max });
  }
  return ranges;
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
    const categories = parseList(params.categories ?? params.category).map((item) =>
      item.toLowerCase(),
    );
    if (categories.some((category) => !CATEGORIES.has(category))) {
      return json(400, { error: 'Invalid category' });
    }

    let priceRanges = parseRanges(params.priceRange);
    if (priceRanges == null) {
      return json(400, { error: 'Invalid priceRange' });
    }
    if (priceRanges.length === 0 && params.priceMax) {
      const parsedPriceMax = parseNumber(params.priceMax);
      if (parsedPriceMax == null || parsedPriceMax < 0) {
        return json(400, { error: 'Invalid priceMax' });
      }
      priceRanges = [{ min: null, max: Math.floor(parsedPriceMax) }];
    }

    let distanceRanges = parseRanges(params.disRange);
    if (distanceRanges == null) {
      return json(400, { error: 'Invalid disRange' });
    }
    if (distanceRanges.length === 0 && params.radius) {
      const parsedRadius = parseNumber(params.radius);
      if (parsedRadius == null || parsedRadius <= 0) {
        return json(400, { error: 'Invalid radius' });
      }
      distanceRanges = [{ min: null, max: Math.floor(parsedRadius) }];
    }

    const sortOptions = parseList(params.sortBy).map((item) => item.toLowerCase());
    if (sortOptions.some((option) => !SORT_OPTIONS.has(option))) {
      return json(400, { error: 'Invalid sortBy' });
    }
    if (sortOptions.length === 0) sortOptions.push('distance');

    const parsedLimit = parseNumber(params.limit);
    const limit = Math.min(Math.max(Math.floor(parsedLimit ?? 20), 1), 50);
    const cursor = params.cursor?.trim() || null;
    if (cursor && Number.isNaN(Date.parse(cursor))) {
      return json(400, { error: 'Invalid cursor' });
    }

    const sqlParams: unknown[] = [lng, lat];
    const conditions = ["ps.status = 'APPROVED'", "ps.visibility = 'PUBLIC'"];

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
    if (categories.length > 0) {
      addCondition((index) => `p.category = ANY($${index}::text[])`, categories);
    }
    if (priceRanges.length > 0) {
      const rangeConditions = priceRanges.map((range) => {
        const parts: string[] = [];
        if (range.min != null) {
          sqlParams.push(range.min);
          parts.push(`COALESCE(p.price_max, p.price_min) >= $${sqlParams.length}`);
        }
        if (range.max != null) {
          sqlParams.push(range.max);
          parts.push(`COALESCE(p.price_min, p.price_max) <= $${sqlParams.length}`);
        }
        return `(${parts.join(' AND ')})`;
      });
      conditions.push(
        `((p.price_min IS NOT NULL OR p.price_max IS NOT NULL) AND (${rangeConditions.join(' OR ')}))`,
      );
    }
    if (distanceRanges.length > 0) {
      const distanceExpression = 'ST_Distance(p.location, ST_MakePoint($1, $2)::geography)';
      const rangeConditions = distanceRanges.map((range) => {
        const parts: string[] = [];
        if (range.min != null) {
          sqlParams.push(range.min);
          parts.push(`${distanceExpression} >= $${sqlParams.length}`);
        }
        if (range.max != null) {
          sqlParams.push(range.max);
          parts.push(`${distanceExpression} < $${sqlParams.length}`);
        }
        return `(${parts.join(' AND ')})`;
      });
      conditions.push(`(${rangeConditions.join(' OR ')})`);
    }
    if (cursor) {
      addCondition((index) => `p.created_at < $${index}::timestamptz`, cursor);
    }

    const sortClauses = sortOptions.map((option) => {
      switch (option) {
        case 'rating':
          return 'COALESCE(p.avg_rating, 0) DESC';
        case 'popular':
          return '"checkinCount" DESC';
        case 'price_asc':
          return 'p.price_min ASC NULLS LAST';
        case 'price_desc':
          return 'p.price_max DESC NULLS LAST';
        case 'newest':
          return 'p.created_at DESC';
        default:
          return '"distanceMeters" ASC';
      }
    });
    const orderClause = [...new Set([...sortClauses, 'p.created_at DESC', 'p.id ASC'])].join(', ');

    sqlParams.push(limit + 1);
    const sql = `
      SELECT
        p.id AS "placeId",
        p.name,
        p.category,
        p.address,
        p.description,
        COALESCE(p.avg_rating, 0)::float AS "avgRating",
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
