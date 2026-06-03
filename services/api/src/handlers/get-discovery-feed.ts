import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

// ── Static vibes list ────────────────────────────────────────────────────────
const VIBES = [
  { id: 'hen_ho', name: 'Hẹn hò', icon: 'heart' },
  { id: 'nhom', name: 'Nhóm', icon: 'group' },
  { id: 'hoc_lam_viec', name: 'Học/Làm việc', icon: 'book' },
  { id: 'chill', name: 'Chill', icon: 'leaf' },
  { id: 'lang_man', name: 'Lãng mạn', icon: 'sparkle' },
  { id: 'khong_gian_xanh', name: 'Không gian xanh', icon: 'tree' },
  { id: 'acoustic', name: 'Acoustic', icon: 'music' },
  { id: 'cafe', name: 'Cafe', icon: 'coffee' },
  { id: 'ngot_ngao', name: 'Ngọt ngào', icon: 'cake' },
];

/**
 * GET /discovery/feed
 *
 * Returns aggregated discovery feed data for the home screen.
 * Sections: weather (TODO), vibes, hotPlaces, recommendedPlaces, friendsActivity
 *
 * Query params:
 * - lat (required) — for weather (later) and distance calculation
 * - lng (required) — for weather (later) and distance calculation
 *
 * lat/lng are used to calculate distance for display only, NOT to filter results.
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    let userId: string;
    try {
      const auth = await extractAuth(event);
      userId = auth.sub;
    } catch {
      return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
    }

    const lat = parseFloat(event.queryStringParameters?.lat || '');
    const lng = parseFloat(event.queryStringParameters?.lng || '');

    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Missing or invalid lat/lng' }) };
    }

    // Run all queries in parallel for speed
    const [hotPlaces, recommendedPlaces, friendsActivity] = await Promise.all([
      fetchHotPlaces(lng, lat),
      fetchRecommendedPlaces(userId, lng, lat),
      fetchFriendsActivity(userId, lng, lat),
    ]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        data: {
          weather: null, // TODO: integrate weather API later
          vibes: VIBES,
          hotPlaces,
          recommendedPlaces,
          friendsActivity,
        },
      }),
    };
  } catch (error) {
    console.error('Error fetching discovery feed:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}

// ── Hot Places: Top check-in count across all places ─────────────────────────
async function fetchHotPlaces(lng: number, lat: number) {
  const sql = `
    SELECT * FROM (
      SELECT
        p.id::text AS "placeId",
        p.name,
        p.category,
        ROUND(p.avg_rating::numeric, 1) AS "avgRating",
        p.rating_count AS "ratingCount",
        p.checkin_count AS "checkinCount",
        p.cover_media_id AS "coverMediaId",
        ST_Y(p.location::geometry) AS lat,
        ST_X(p.location::geometry) AS lng,
        ROUND(ST_Distance(p.location, ST_MakePoint($1, $2)::geography)::numeric) AS "distanceMeters",
        false AS "isCandidate"
      FROM places p
      WHERE p.checkin_count > 0

      UNION ALL

      SELECT
        pc.id::text AS "placeId",
        pc.name,
        pc.category,
        ROUND(pc.avg_rating::numeric, 1) AS "avgRating",
        pc.rating_count AS "ratingCount",
        pc.checkin_count AS "checkinCount",
        pc.cover_media_id AS "coverMediaId",
        ST_Y(pc.location::geometry) AS lat,
        ST_X(pc.location::geometry) AS lng,
        ROUND(ST_Distance(pc.location, ST_MakePoint($1, $2)::geography)::numeric) AS "distanceMeters",
        true AS "isCandidate"
      FROM place_candidates pc
      WHERE pc.checkin_count > 0
    ) combined
    ORDER BY "checkinCount" DESC
    LIMIT 10;
  `;
  const result = await query(sql, [lng, lat]);
  return result.rows;
}

// ── Recommended: Category/Vibe match based on user's check-in history ────────
async function fetchRecommendedPlaces(userId: string, lng: number, lat: number) {
  // Strategy: Find categories from user's past check-ins,
  // then find places matching those categories that the user hasn't visited.
  // No radius filter — show best matches regardless of distance.
  const sql = `
    WITH user_categories AS (
      SELECT DISTINCT COALESCE(p.category, pc.category) AS category
      FROM check_ins ci
      LEFT JOIN places p ON p.id = ci.place_id
      LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
      WHERE ci.user_id = $1
        AND COALESCE(p.category, pc.category) IS NOT NULL
    ),
    user_visited_places AS (
      SELECT DISTINCT COALESCE(ci.place_id, ci.candidate_id) AS visited_id
      FROM check_ins ci
      WHERE ci.user_id = $1
    )
    SELECT * FROM (
      SELECT
        p.id::text AS "placeId",
        p.name,
        p.category,
        ROUND(p.avg_rating::numeric, 1) AS "avgRating",
        p.rating_count AS "ratingCount",
        p.checkin_count AS "checkinCount",
        p.cover_media_id AS "coverMediaId",
        ST_Y(p.location::geometry) AS lat,
        ST_X(p.location::geometry) AS lng,
        ROUND(ST_Distance(p.location, ST_MakePoint($2, $3)::geography)::numeric) AS "distanceMeters",
        false AS "isCandidate"
      FROM places p
      WHERE p.category IN (SELECT category FROM user_categories)
        AND p.id NOT IN (SELECT visited_id FROM user_visited_places WHERE visited_id IS NOT NULL)

      UNION ALL

      SELECT
        pc.id::text AS "placeId",
        pc.name,
        pc.category,
        ROUND(pc.avg_rating::numeric, 1) AS "avgRating",
        pc.rating_count AS "ratingCount",
        pc.checkin_count AS "checkinCount",
        pc.cover_media_id AS "coverMediaId",
        ST_Y(pc.location::geometry) AS lat,
        ST_X(pc.location::geometry) AS lng,
        ROUND(ST_Distance(pc.location, ST_MakePoint($2, $3)::geography)::numeric) AS "distanceMeters",
        true AS "isCandidate"
      FROM place_candidates pc
      WHERE pc.category IN (SELECT category FROM user_categories)
        AND pc.id NOT IN (SELECT visited_id FROM user_visited_places WHERE visited_id IS NOT NULL)
    ) combined
    ORDER BY "avgRating" DESC, "checkinCount" DESC
    LIMIT 10;
  `;
  const result = await query(sql, [userId, lng, lat]);
  return result.rows;
}

// ── Friends Activity: Places friends have checked in ─────────────────────────
async function fetchFriendsActivity(userId: string, lng: number, lat: number) {
  const sql = `
    SELECT
      COALESCE(p.id, pc.id)::text AS "placeId",
      COALESCE(p.name, pc.name) AS name,
      COALESCE(p.category, pc.category) AS category,
      ROUND(COALESCE(p.avg_rating, pc.avg_rating)::numeric, 1) AS "avgRating",
      COALESCE(p.price_min, pc.price_min) AS "priceMin",
      COALESCE(p.price_max, pc.price_max) AS "priceMax",
      COALESCE(p.cover_media_id, pc.cover_media_id) AS "coverMediaId",
      COALESCE(
        ST_Y(p.location::geometry),
        ST_Y(pc.location::geometry)
      ) AS lat,
      COALESCE(
        ST_X(p.location::geometry),
        ST_X(pc.location::geometry)
      ) AS lng,
      ROUND(ST_Distance(
        COALESCE(p.location, pc.location),
        ST_MakePoint($2, $3)::geography
      )::numeric) AS "distanceMeters",
      CASE WHEN ci.candidate_id IS NOT NULL THEN true ELSE false END AS "isCandidate",
      COUNT(DISTINCT ci.user_id)::integer AS "friendCheckinCount",
      array_agg(DISTINCT u.avatar_url) FILTER (WHERE u.avatar_url IS NOT NULL) AS "friendAvatars"
    FROM check_ins ci
    JOIN friendships f
      ON f.user_id = $1
      AND f.friend_id = ci.user_id
      AND f.status = 'ACCEPTED'
    JOIN users u ON u.id = ci.user_id
    LEFT JOIN places p ON p.id = ci.place_id
    LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
    WHERE ci.visibility = 'FRIENDS'
      AND COALESCE(p.location, pc.location) IS NOT NULL
    GROUP BY
      COALESCE(p.id, pc.id),
      COALESCE(p.name, pc.name),
      COALESCE(p.category, pc.category),
      COALESCE(p.avg_rating, pc.avg_rating),
      COALESCE(p.price_min, pc.price_min),
      COALESCE(p.price_max, pc.price_max),
      COALESCE(p.cover_media_id, pc.cover_media_id),
      COALESCE(ST_Y(p.location::geometry), ST_Y(pc.location::geometry)),
      COALESCE(ST_X(p.location::geometry), ST_X(pc.location::geometry)),
      ST_Distance(COALESCE(p.location, pc.location), ST_MakePoint($2, $3)::geography),
      CASE WHEN ci.candidate_id IS NOT NULL THEN true ELSE false END
    ORDER BY "friendCheckinCount" DESC
    LIMIT 10;
  `;
  const result = await query(sql, [userId, lng, lat]);
  return result.rows;
}
