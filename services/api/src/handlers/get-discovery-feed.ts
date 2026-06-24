import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

const VIBES = [
  { id: 'hen_ho', name: 'Hẹn hò', icon: 'heart' },
  { id: 'nhom_ban', name: 'Nhóm bạn', icon: 'group' },
  { id: 'hoc_lam_viec', name: 'Học/Làm việc', icon: 'menu_book' },
  { id: 'chill', name: 'Chill', icon: 'nightlight' },
  { id: 'lang_man', name: 'Lãng mạn', icon: 'auto_awesome' },
  { id: 'khong_gian_xanh', name: 'Không gian xanh', icon: 'eco' },
  { id: 'acoustic', name: 'Acoustic', icon: 'music_note' },
  { id: 'cafe', name: 'Cafe', icon: 'coffee' },
  { id: 'ngot_ngao', name: 'Ngọt ngào', icon: 'cake' },
];

/**
 * GET /discovery/feed
 *
 * BFF endpoint returning all data for the Discovery screen:
 * - vibes (category tags)
 * - hotPlaces (sorted by checkin_count)
 * - recommendedPlaces (category match, not visited)
 * - friendsActivity (friends' recent check-ins)
 *
 * Query params:
 *   - lat (required): user latitude
 *   - lng (required): user longitude
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    let userId: string;
    try {
      const auth = await extractAuth(event);
      userId = auth.sub;
    } catch {
      return {
        statusCode: 401,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const lat = parseFloat(event.queryStringParameters?.lat || '');
    const lng = parseFloat(event.queryStringParameters?.lng || '');

    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Missing or invalid lat/lng' }),
      };
    }

    // 1. Hot Places — global, sorted by check-in count
    const hotSql = `
      SELECT
        p.id AS "placeId",
        p.name,
        p.category,
        COALESCE(p.avg_rating, 0) AS "avgRating",
        COALESCE(p.rating_count, 0) AS "ratingCount",
        (SELECT COUNT(*)::integer FROM check_ins ci WHERE ci.place_id = p.id) AS "checkinCount",
        p.cover_media_id AS "coverMediaId",
        ST_Y(p.location::geometry) AS lat,
        ST_X(p.location::geometry) AS lng,
        ST_Distance(p.location, ST_MakePoint($1, $2)::geography)::integer AS "distanceMeters",
        false AS "isCandidate"
      FROM places p
      JOIN place_settings ps ON ps.place_id = p.id
      WHERE ps.status = 'APPROVED'
      ORDER BY "checkinCount" DESC
      LIMIT 10;
    `;
    const hotResult = await query(hotSql, [lng, lat]);

    // 2. Recommended Places — same categories user frequents but hasn't visited (with fallback for new users)
    const recSql = `
      WITH user_categories AS (
        SELECT DISTINCT COALESCE(p.category, pc.category) AS category
        FROM check_ins ci
        LEFT JOIN places p ON p.id = ci.place_id
        LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
        WHERE ci.user_id = $3
      ),
      visited_places AS (
        SELECT DISTINCT place_id FROM check_ins WHERE user_id = $3 AND place_id IS NOT NULL
      ),
      has_history AS (
        SELECT EXISTS(SELECT 1 FROM user_categories) AS val
      )
      SELECT
        p.id AS "placeId",
        p.name,
        p.category,
        COALESCE(p.avg_rating, 0) AS "avgRating",
        COALESCE(p.rating_count, 0) AS "ratingCount",
        (SELECT COUNT(*)::integer FROM check_ins ci WHERE ci.place_id = p.id) AS "checkinCount",
        p.cover_media_id AS "coverMediaId",
        ST_Y(p.location::geometry) AS lat,
        ST_X(p.location::geometry) AS lng,
        ST_Distance(p.location, ST_MakePoint($1, $2)::geography)::integer AS "distanceMeters",
        false AS "isCandidate"
      FROM places p
      JOIN place_settings ps ON ps.place_id = p.id
      CROSS JOIN has_history hh
      WHERE ps.status = 'APPROVED'
        AND (
          hh.val = false 
          OR p.category IN (SELECT category FROM user_categories)
        )
        AND p.id NOT IN (SELECT place_id FROM visited_places)
      ORDER BY 
        CASE WHEN hh.val = false THEN COALESCE(p.avg_rating, 0) ELSE 0 END DESC,
        "distanceMeters" ASC
      LIMIT 10;
    `;
    const recResult = await query(recSql, [lng, lat, userId]);

    // 3. Friends Activity — friends' check-ins aggregated by place
    const friendsSql = `
      SELECT
        COALESCE(p.id, pc.id)::text AS "placeId",
        COALESCE(p.name, pc.name) AS name,
        COALESCE(p.category, pc.category) AS category,
        COALESCE(p.avg_rating, 0) AS "avgRating",
        COALESCE(p.price_min, pc.price_min) AS "priceMin",
        COALESCE(p.price_max, pc.price_max) AS "priceMax",
        COALESCE(p.cover_media_id, pc.media_id) AS "coverMediaId",
        COALESCE(ST_Y(p.location::geometry), ST_Y(pc.location::geometry)) AS lat,
        COALESCE(ST_X(p.location::geometry), ST_X(pc.location::geometry)) AS lng,
        ST_Distance(
          COALESCE(p.location, pc.location),
          ST_MakePoint($1, $2)::geography
        )::integer AS "distanceMeters",
        CASE WHEN ci.candidate_id IS NOT NULL THEN true ELSE false END AS "isCandidate",
        COUNT(DISTINCT ci.user_id)::integer AS "friendCheckinCount",
        ARRAY_AGG(DISTINCT u.avatar_url) FILTER (WHERE u.avatar_url IS NOT NULL) AS "friendAvatars"
      FROM check_ins ci
      JOIN users u ON u.id = ci.user_id
      LEFT JOIN places p ON p.id = ci.place_id
      LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
      WHERE ci.visibility = 'FRIENDS'
        AND ci.user_id IN (
          SELECT friend_id FROM friendships
          WHERE user_id = $3 AND status = 'ACCEPTED'
        )
        AND COALESCE(p.location, pc.location) IS NOT NULL
      GROUP BY
        COALESCE(p.id, pc.id),
        COALESCE(p.name, pc.name),
        COALESCE(p.category, pc.category),
        COALESCE(p.avg_rating, 0),
        COALESCE(p.price_min, pc.price_min),
        COALESCE(p.price_max, pc.price_max),
        COALESCE(p.cover_media_id, pc.media_id),
        COALESCE(ST_Y(p.location::geometry), ST_Y(pc.location::geometry)),
        COALESCE(ST_X(p.location::geometry), ST_X(pc.location::geometry)),
        COALESCE(p.location, pc.location),
        CASE WHEN ci.candidate_id IS NOT NULL THEN true ELSE false END
      ORDER BY "friendCheckinCount" DESC
      LIMIT 10;
    `;
    const friendsResult = await query(friendsSql, [lng, lat, userId]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        data: {
          weather: null,
          vibes: VIBES,
          hotPlaces: hotResult.rows,
          recommendedPlaces: recResult.rows,
          friendsActivity: friendsResult.rows,
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
