import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /places/{id} — BFF for Place Detail screen.
 *
 * Returns all data needed for the UI in a single request:
 * - Basic info (name, address, hours, price, description, etc.)
 * - Rating (avg_rating, rating_count)
 * - Friends' check-ins (max 10)
 * - Friends' reviews (max 5)
 * - Other reviews (max 10)
 * - Photos from check-ins (max 20)
 * - Current user's review (if any)
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

    const placeId = event.pathParameters?.id;
    if (!placeId) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Missing place id' }) };
    }

    // ── 1. Try approved place first ──────────────────────────────
    const placeSql = `
      SELECT
        p.id,
        p.name,
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
        p.cover_media_id,
        ps.visibility,
        ps.status,
        ps.is_featured,
        ps.is_verified,
        (SELECT COUNT(*)::integer FROM check_ins c WHERE c.place_id = p.id) AS checkin_count
      FROM places p
      LEFT JOIN place_settings ps ON p.id = ps.place_id
      WHERE p.id = $1 AND (ps.status = 'APPROVED' OR ps.status IS NULL)
    `;
    const placeResult = await query(placeSql, [placeId]);

    let placeData: any = null;
    let isCandidate = false;
    let targetCol = 'place_id';

    if (placeResult.rows.length > 0) {
      const p = placeResult.rows[0];
      placeData = {
        id: p.id,
        name: p.name,
        category: p.category,
        address: p.address,
        coordinates: { lat: parseFloat(String(p.lat)), lng: parseFloat(String(p.lng)) },
        openTime: p.open_time,
        closeTime: p.close_time,
        priceMin: p.price_min,
        priceMax: p.price_max,
        phoneNumber: p.phone_number,
        description: p.description,
        coverMediaId: p.cover_media_id,
        isCandidate: false,
        avgRating: parseFloat(String(p.avg_rating || 0)),
        ratingCount: parseInt(String(p.rating_count || 0), 10),
        visibility: p.visibility,
        status: p.status,
        isFeatured: p.is_featured,
        isVerified: p.is_verified,
        checkinCount: p.checkin_count,
        vibes: p.metadata?.vibes || [],
        services: p.metadata?.services || [],
      };
    } else {
      // ── 2. Fallback to candidate ──────────────────────────────
      const candidateSql = `
        SELECT
          pc.id,
          pc.name,
          pc.category,
          pc.address,
          ST_Y(pc.location::geometry) AS lat,
          ST_X(pc.location::geometry) AS lng,
          pc.open_time,
          pc.close_time,
          pc.price_min,
          pc.price_max,
          pc.phone_number,
          pc.description,
          pc.metadata,
          pc.avg_rating,
          pc.rating_count,
          pc.media_id,
          pc.status,
          (SELECT COUNT(*)::integer FROM check_ins c WHERE c.candidate_id = pc.id) AS checkin_count
        FROM place_candidates pc
        WHERE pc.id = $1
      `;
      const candidateResult = await query(candidateSql, [placeId]);
      if (candidateResult.rows.length === 0) {
        return { statusCode: 404, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Place not found' }) };
      }

      isCandidate = true;
      targetCol = 'candidate_id';
      const c = candidateResult.rows[0];
      placeData = {
        id: c.id,
        name: c.name,
        category: c.category,
        address: c.address,
        coordinates: { lat: parseFloat(String(c.lat)), lng: parseFloat(String(c.lng)) },
        openTime: c.open_time,
        closeTime: c.close_time,
        priceMin: c.price_min,
        priceMax: c.price_max,
        phoneNumber: c.phone_number,
        description: c.description,
        coverMediaId: c.media_id,
        isCandidate: true,
        avgRating: parseFloat(String(c.avg_rating || 0)),
        ratingCount: parseInt(String(c.rating_count || 0), 10),
        visibility: 'FRIENDS',
        status: c.status,
        isFeatured: false,
        isVerified: false,
        checkinCount: c.checkin_count,
        vibes: c.metadata?.vibes || [],
        services: c.metadata?.services || [],
      };
    }

    // ── 3. Friends' check-ins (max 10) ──────────────────────────
    const friendCheckinsSql = `
      SELECT
        ci.id,
        ci.user_id AS "userId",
        u.display_name AS "userName",
        u.avatar_url AS "userAvatar",
        ci.media_id AS "mediaId",
        ci.caption,
        ci.rating,
        ci.created_at AS "createdAt"
      FROM check_ins ci
      JOIN users u ON u.id = ci.user_id
      WHERE ci.${targetCol} = $1
        AND ci.user_id IN (
          SELECT friend_id FROM friendships
          WHERE user_id = $2 AND status = 'ACCEPTED'
          UNION ALL SELECT $2
        )
      ORDER BY ci.created_at DESC
      LIMIT 10;
    `;
    const friendCheckinsResult = await query(friendCheckinsSql, [placeId, userId]);

    // ── 4. Friends' reviews (max 5) ─────────────────────────────
    const friendReviewsSql = `
      SELECT
        r.id,
        r.user_id AS "userId",
        u.display_name AS "userName",
        u.avatar_url AS "userAvatar",
        r.rating,
        r.content,
        r.is_featured AS "isFeatured",
        r.created_at AS "createdAt"
      FROM reviews r
      JOIN users u ON u.id = r.user_id
      WHERE r.${targetCol} = $1
        AND r.user_id IN (
          SELECT friend_id FROM friendships
          WHERE user_id = $2 AND status = 'ACCEPTED'
        )
        AND r.user_id != $2
      ORDER BY r.created_at DESC
      LIMIT 5;
    `;
    const friendReviewsResult = await query(friendReviewsSql, [placeId, userId]);

    // ── 5. Other reviews (non-friends, max 10) ──────────────────
    const otherReviewsSql = `
      SELECT
        r.id,
        r.user_id AS "userId",
        u.display_name AS "userName",
        u.avatar_url AS "userAvatar",
        r.rating,
        r.content,
        r.is_featured AS "isFeatured",
        r.created_at AS "createdAt"
      FROM reviews r
      JOIN users u ON u.id = r.user_id
      WHERE r.${targetCol} = $1
        AND r.user_id != $2
        AND r.user_id NOT IN (
          SELECT friend_id FROM friendships
          WHERE user_id = $2 AND status = 'ACCEPTED'
        )
      ORDER BY r.is_featured DESC, r.created_at DESC
      LIMIT 10;
    `;
    const otherReviewsResult = await query(otherReviewsSql, [placeId, userId]);

    // ── 6. Photos from check-ins (max 20) ───────────────────────
    const photosSql = `
      SELECT
        ci.media_id AS "mediaId",
        ci.user_id AS "userId",
        u.display_name AS "userName",
        ci.caption,
        ci.created_at AS "createdAt"
      FROM check_ins ci
      JOIN users u ON u.id = ci.user_id
      WHERE ci.${targetCol} = $1
        AND ci.media_id IS NOT NULL
      ORDER BY ci.created_at DESC
      LIMIT 20;
    `;
    const photosResult = await query(photosSql, [placeId]);

    // ── 7. Current user's review ────────────────────────────────
    const myReviewSql = `
      SELECT
        r.id,
        r.rating,
        r.content,
        r.created_at AS "createdAt",
        r.updated_at AS "updatedAt"
      FROM reviews r
      WHERE r.${targetCol} = $1 AND r.user_id = $2
      LIMIT 1;
    `;
    const myReviewResult = await query(myReviewSql, [placeId, userId]);

    // ── 8. Build response ───────────────────────────────────────
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          ...placeData,
          friendCheckins: friendCheckinsResult.rows,
          friendReviews: friendReviewsResult.rows,
          otherReviews: otherReviewsResult.rows,
          photos: photosResult.rows,
          myReview: myReviewResult.rows[0] || null,
        },
      }),
    };
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Missing auth context')) {
      return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
    }
    console.error('Failed to get place detail:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
