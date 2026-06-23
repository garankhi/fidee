import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

/**
 * GET /map/feed
 * Returns recent check-ins from the user's friends and the user themselves,
 * within a given radius.
 *
 * Query params:
 * - lat: latitude (required)
 * - lng: longitude (required)
 * - radius: radius in meters (optional, default 5000)
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
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const lat = parseFloat(event.queryStringParameters?.lat || '');
    const lng = parseFloat(event.queryStringParameters?.lng || '');
    const radius = parseInt(event.queryStringParameters?.radius || '5000', 10);

    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return { statusCode: 400, body: JSON.stringify({ error: 'Missing or invalid lat/lng' }) };
    }

    const sql = `
      WITH feed_items AS (
        SELECT
          ci.id::text as id,
          ci.caption,
          ci.created_at as "createdAt",
          ci.media_id as "mediaId",
          ci.media_type as "mediaType",
          u.id as "userId",
          u.display_name as "userName",
          u.avatar_url as "userAvatar",
          COALESCE(p.id, pc.id)::text as "placeId",
          COALESCE(p.name, pc.name) as "placeName",
          COALESCE(p.category, pc.category) as category,
          COALESCE(p.address, pc.address) as address,
          COALESCE(ST_Y(p.location::geometry), ST_Y(pc.location::geometry)) AS lat,
          COALESCE(ST_X(p.location::geometry), ST_X(pc.location::geometry)) AS lng,
          COALESCE(pc.visibility, ps.visibility, ci.visibility) as visibility,
          ci.visibility as "checkinVisibility",
          CASE WHEN ci.candidate_id IS NOT NULL THEN true ELSE false END as "isCandidate",
          COALESCE(pc.created_by, p.created_by) as "createdBy",
          creator.display_name as "createdByName",
          creator.avatar_url as "createdByAvatar",
          pc.status as "candidateStatus",
          COUNT(*) OVER (PARTITION BY COALESCE(p.id, pc.id))::integer as "placeCheckinCount",
          recent_activity."recentAvatars",
          recent_activity."recentUserNames"
        FROM check_ins ci
        JOIN users u ON u.id = ci.user_id
        LEFT JOIN places p ON p.id = ci.place_id
        LEFT JOIN place_settings ps ON ps.place_id = p.id
        LEFT JOIN place_candidates pc ON pc.id = ci.candidate_id
        LEFT JOIN users creator ON creator.id = COALESCE(pc.created_by, p.created_by)
        LEFT JOIN LATERAL (
          SELECT
            ARRAY_AGG(activity.avatar_url) FILTER (WHERE activity.avatar_url IS NOT NULL) as "recentAvatars",
            ARRAY_AGG(activity.display_name) FILTER (WHERE activity.display_name IS NOT NULL) as "recentUserNames"
          FROM (
            SELECT
              u2.avatar_url,
              u2.display_name,
              ci2.created_at
            FROM check_ins ci2
            JOIN users u2 ON u2.id = ci2.user_id
            WHERE (
                (p.id IS NOT NULL AND ci2.place_id = p.id)
                OR (pc.id IS NOT NULL AND ci2.candidate_id = pc.id)
              )
              AND (
                ci2.user_id = $1
                OR (
                  ci2.visibility = 'FRIENDS'
                  AND ci2.user_id IN (
                    SELECT friend_id FROM friendships
                    WHERE user_id = $1 AND status = 'ACCEPTED'
                  )
                  AND (
                    ci2.audience_type = 'ALL_FRIENDS'
                    OR EXISTS (
                      SELECT 1 FROM check_in_recipients cir2
                      WHERE cir2.checkin_id = ci2.id
                        AND cir2.recipient_user_id = $1
                    )
                  )
                )
              )
            ORDER BY ci2.created_at DESC
            LIMIT 3
          ) activity
        ) recent_activity ON true
        WHERE (
            ci.user_id = $1
            OR (
              ci.visibility = 'FRIENDS'
              AND ci.user_id IN (
                SELECT friend_id FROM friendships
                WHERE user_id = $1 AND status = 'ACCEPTED'
              )
              AND (
                ci.audience_type = 'ALL_FRIENDS'
                OR EXISTS (
                  SELECT 1 FROM check_in_recipients cir
                  WHERE cir.checkin_id = ci.id
                    AND cir.recipient_user_id = $1
                )
              )
            )
          )
          AND COALESCE(p.location, pc.location) IS NOT NULL
          AND (pc.id IS NULL OR pc.visibility = 'FRIENDS' OR pc.created_by = $1)
          AND ST_DWithin(COALESCE(p.location, pc.location), ST_MakePoint($2, $3)::geography, $4)

        UNION ALL

        SELECT
          ('candidate-' || pc.id)::text as id,
          '' as caption,
          pc.created_at as "createdAt",
          '' as "mediaId",
          NULL::text as "mediaType",
          creator.id as "userId",
          creator.display_name as "userName",
          creator.avatar_url as "userAvatar",
          pc.id::text as "placeId",
          pc.name as "placeName",
          pc.category,
          pc.address,
          ST_Y(pc.location::geometry) AS lat,
          ST_X(pc.location::geometry) AS lng,
          pc.visibility,
          NULL::text as "checkinVisibility",
          true as "isCandidate",
          pc.created_by as "createdBy",
          creator.display_name as "createdByName",
          creator.avatar_url as "createdByAvatar",
          pc.status as "candidateStatus",
          0 as "placeCheckinCount",
          ARRAY_REMOVE(ARRAY[creator.avatar_url], NULL) as "recentAvatars",
          ARRAY_REMOVE(ARRAY[creator.display_name], NULL) as "recentUserNames"
        FROM place_candidates pc
        JOIN users creator ON creator.id = pc.created_by
        WHERE pc.location IS NOT NULL
          AND (pc.visibility = 'FRIENDS' OR pc.created_by = $1)
          AND ST_DWithin(pc.location, ST_MakePoint($2, $3)::geography, $4)
          AND NOT EXISTS (
            SELECT 1 FROM check_ins ci_existing
            WHERE ci_existing.candidate_id = pc.id
              AND (
                ci_existing.user_id = $1
                OR (
                  ci_existing.visibility = 'FRIENDS'
                  AND ci_existing.user_id IN (
                    SELECT friend_id FROM friendships
                    WHERE user_id = $1 AND status = 'ACCEPTED'
                  )
                  AND (
                    ci_existing.audience_type = 'ALL_FRIENDS'
                    OR EXISTS (
                      SELECT 1 FROM check_in_recipients cir_existing
                      WHERE cir_existing.checkin_id = ci_existing.id
                        AND cir_existing.recipient_user_id = $1
                    )
                  )
                )
              )
          )
      )
      SELECT * FROM feed_items
      ORDER BY "createdAt" DESC
      LIMIT 50;
    `;

    const result = await query(sql, [userId, lng, lat, radius]);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({ data: result.rows }),
    };
  } catch (error) {
    console.error('Error fetching map feed:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
