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
  terms: string[];
  categories?: string[];
};

const VIBE_MAP: Record<string, VibeFilter> = {
  hen_ho: {
    terms: ['hẹn hò', 'hen ho', 'lãng mạn', 'lang man', 'romantic', 'couple', 'thân mật', 'intimate', 'ánh nến', 'kỷ niệm'],
  },
  nhom_ban: {
    terms: ['nhóm', 'nhom', 'bạn bè', 'ban be', 'tụ tập', 'tu tap', 'họp mặt', 'hop mat', 'gia đình', 'gia dinh', 'liên hoan', 'lien hoan', 'sinh nhật', 'sinh nhat', 'tiệc công ty', 'tiec cong ty', 'phòng riêng', 'phong rieng', 'boardgame', 'karaoke'],
  },
  nhom: {
    terms: ['nhóm', 'nhom', 'bạn bè', 'ban be', 'tụ tập', 'tu tap', 'họp mặt', 'hop mat', 'gia đình', 'gia dinh', 'phòng riêng', 'phong rieng'],
  },
  hoc_lam_viec: {
    terms: ['học', 'hoc', 'làm việc', 'lam viec', 'work', 'work-friendly', 'workbench', 'deadline', 'tập trung', 'tap trung', 'yên tĩnh', 'yen tinh', 'ổ cắm', 'o cam', 'phòng riêng yên tĩnh', 'phong rieng yen tinh', 'máy chiếu', 'may chieu'],
  },
  chill: {
    terms: ['chill', 'thư giãn', 'thu gian', 'relaxed', 'nhẹ nhàng', 'nhe nhang', 'yên tĩnh', 'yen tinh', 'lộng gió', 'long gio', 'thoáng đãng', 'thoang dang', 'ấm cúng', 'am cung', 'hoài cổ', 'hoai co', 'vintage'],
  },
  lang_man: {
    terms: ['lãng mạn', 'lang man', 'romantic', 'hẹn hò', 'hen ho', 'ánh nến', 'anh nen', 'thân mật', 'than mat', 'intimate', 'kỷ niệm', 'ky niem', 'sang trọng', 'sang trong'],
  },
  khong_gian_xanh: {
    terms: ['không gian xanh', 'khong gian xanh', 'sân vườn', 'san vuon', 'ngoài trời', 'ngoai troi', 'thiên nhiên', 'thien nhien', 'cây xanh', 'cay xanh', 'hồ cá', 'ho ca', 'koi', 'ven sông', 'ven song', 'sông nước', 'song nuoc', 'rooftop', 'sân thượng', 'san thuong', 'terrace'],
  },
  acoustic: {
    terms: ['acoustic', 'nhạc sống', 'nhac song', 'live music', 'nhạc jazz', 'nhac jazz', 'jazz', 'âm nhạc', 'am nhac', 'music', 'nhạc nền', 'nhac nen'],
  },
  cafe: {
    terms: ['cafe', 'coffee', 'cà phê', 'ca phe', 'barista', 'cold brew', 'espresso', 'trà', 'tra', 'tea'],
    categories: ['cafe'],
  },
  ngot_ngao: {
    terms: ['ngọt', 'ngot', 'bánh', 'banh', 'dessert', 'cake', 'trà sữa', 'tra sua', 'bubble tea', 'hồng trà', 'hong tra', 'kem', 'chè', 'che'],
  },
  dating: {
    terms: ['hẹn hò', 'hen ho', 'lãng mạn', 'lang man', 'romantic', 'couple'],
  },
  group: {
    terms: ['nhóm', 'nhom', 'bạn bè', 'ban be', 'tụ tập', 'tu tap', 'họp mặt', 'hop mat', 'gia đình', 'gia dinh'],
  },
  study: {
    terms: ['học', 'hoc', 'làm việc', 'lam viec', 'work', 'deadline', 'tập trung', 'tap trung', 'yên tĩnh', 'yen tinh', 'ổ cắm', 'o cam'],
  },
  outdoor: {
    terms: ['ngoài trời', 'ngoai troi', 'sân vườn', 'san vuon', 'rooftop', 'sân thượng', 'san thuong', 'terrace'],
  },
  cozy: {
    terms: ['ấm cúng', 'am cung', 'cozy', 'thân mật', 'than mat', 'hoài cổ', 'hoai co'],
  },
  healthy: {
    terms: ['healthy', 'lành mạnh', 'lanh manh', 'chay', 'rau', 'salad'],
  },
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
  const normalized = normalizeSearchText(trimmed);
  return (
    VIBE_MAP[normalized.replace(/[\s/]+/g, '_')] ?? {
      terms: [...new Set([trimmed, normalized])],
    }
  );
}

function wildcardTerms(terms: string[]): string[] {
  return [...new Set(terms.map((term) => term.trim()).filter(Boolean))].map(
    (term) => `%${term}%`,
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
      if (vibeFilter.terms.length > 0) {
        sqlParams.push(wildcardTerms(vibeFilter.terms));
        vibeConditions.push(
          `concat_ws(' ', p.category, p.name, p.normalized_name, p.description, p.metadata->>'vibe', p.metadata->>'features', p.metadata->>'vibes', p.metadata->>'services') ILIKE ANY($${sqlParams.length}::text[])`,
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
