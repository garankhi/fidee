import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

type CheckinAudienceType = 'ALL_FRIENDS' | 'DIRECT' | 'PRIVATE';

interface ParsedAudience {
  type: CheckinAudienceType;
  friendIds: string[];
}

class BadRequestError extends Error {}
class ForbiddenError extends Error {}

function parseAudience(value: unknown): ParsedAudience {
  if (value === undefined || value === null) {
    return { type: 'ALL_FRIENDS', friendIds: [] };
  }
  if (typeof value !== 'object' || Array.isArray(value)) {
    throw new BadRequestError('audience must be an object');
  }

  const body = value as Record<string, unknown>;
  const type = body.type;
  if (type !== 'ALL_FRIENDS' && type !== 'DIRECT' && type !== 'PRIVATE') {
    throw new BadRequestError('audience.type must be ALL_FRIENDS, DIRECT, or PRIVATE');
  }

  if (type !== 'DIRECT') return { type, friendIds: [] };

  const rawFriendIds = body.friendIds;
  if (!Array.isArray(rawFriendIds)) {
    throw new BadRequestError('DIRECT audience requires friendIds');
  }

  const friendIds = [
    ...new Set(
      rawFriendIds
        .filter((id): id is string => typeof id === 'string' && id.trim().length > 0)
        .map((id) => id.trim()),
    ),
  ];
  if (friendIds.length === 0) {
    throw new BadRequestError('DIRECT audience requires at least one friend');
  }
  if (friendIds.length > 10) {
    throw new BadRequestError('DIRECT audience supports at most 10 friends');
  }

  return { type: 'DIRECT', friendIds };
}

async function assertAcceptedFriends(userId: string, friendIds: string[]): Promise<void> {
  if (friendIds.length === 0) return;

  const result = await query<{ friend_id: string }>(
    `
      SELECT friend_id
      FROM friendships
      WHERE user_id = $1
        AND friend_id = ANY($2::text[])
        AND status = 'ACCEPTED';
    `,
    [userId, friendIds],
  );

  if (result.rows.length !== friendIds.length) {
    throw new ForbiddenError('DIRECT audience can only target accepted friends');
  }
}

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const auth = await extractAuth(event);

    const body = JSON.parse(event.body || '{}');
    const {
      place_id,
      candidate_id,
      media_id,
      gps_lat,
      gps_lng,
      gps_accuracy,
      caption,
      rating,
      visibility = 'FRIENDS',
    } = body;

    if (!place_id && !candidate_id) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Either place_id or candidate_id is required' }),
      };
    }
    if (place_id && candidate_id) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Use only one of place_id or candidate_id' }),
      };
    }
    if (!media_id) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'media_id is required' }),
      };
    }
    if (gps_lat == null || gps_lng == null) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'gps_lat and gps_lng are required' }),
      };
    }
    if (!['FRIENDS', 'PRIVATE'].includes(visibility)) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'visibility must be FRIENDS or PRIVATE' }),
      };
    }

    const audience = parseAudience(body.audience);
    await assertAcceptedFriends(auth.sub, audience.friendIds);
    const effectiveVisibility = audience.type === 'PRIVATE' ? 'PRIVATE' : visibility;

    const insertSql = `
      INSERT INTO check_ins (
        user_id, place_id, candidate_id, media_id, gps_lat, gps_lng,
        gps_accuracy, caption, rating, visibility, audience_type
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING id, created_at;
    `;
    const result = await query(insertSql, [
      auth.sub,
      place_id || null,
      candidate_id || null,
      media_id,
      gps_lat,
      gps_lng,
      gps_accuracy || null,
      caption || null,
      rating || null,
      effectiveVisibility,
      audience.type,
    ]);

    const checkinId = result.rows[0].id;
    if (audience.type === 'DIRECT') {
      await query(
        `
          INSERT INTO check_in_recipients (checkin_id, recipient_user_id)
          SELECT $1::uuid, unnest($2::text[]);
        `,
        [checkinId, audience.friendIds],
      );
    }

    // Update counters in parallel: user + place/candidate
    const counterUpdates: Promise<unknown>[] = [
      query('UPDATE users SET checkin_count = checkin_count + 1 WHERE id = $1;', [auth.sub]),
    ];

    const ratingVal = rating != null ? Number(rating) : null;

    if (place_id) {
      counterUpdates.push(
        query(
          `
        UPDATE places SET
          checkin_count = checkin_count + 1,
          rating_count = CASE WHEN $2::int IS NOT NULL THEN rating_count + 1 ELSE rating_count END,
          avg_rating = CASE
            WHEN $2::int IS NOT NULL AND rating_count > 0
              THEN (avg_rating * rating_count + $2::int) / (rating_count + 1)
            WHEN $2::int IS NOT NULL
              THEN $2::double precision
            ELSE avg_rating END,
          cover_media_id = COALESCE(cover_media_id, $3)
        WHERE id = $1
      `,
          [place_id, ratingVal, media_id],
        ),
      );
    }

    if (candidate_id) {
      counterUpdates.push(
        query(
          `
        UPDATE place_candidates SET
          checkin_count = checkin_count + 1,
          rating_count = CASE WHEN $2::int IS NOT NULL THEN rating_count + 1 ELSE rating_count END,
          avg_rating = CASE
            WHEN $2::int IS NOT NULL AND rating_count > 0
              THEN (avg_rating * rating_count + $2::int) / (rating_count + 1)
            WHEN $2::int IS NOT NULL
              THEN $2::double precision
            ELSE avg_rating END,
          cover_media_id = COALESCE(cover_media_id, $3)
        WHERE id = $1
      `,
          [candidate_id, ratingVal, media_id],
        ),
      );
    }

    await Promise.all(counterUpdates);

    return {
      statusCode: 201,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          id: checkinId,
          created_at: result.rows[0].created_at,
        },
      }),
    };
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Missing auth context')) {
      return {
        statusCode: 401,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }
    if (error instanceof BadRequestError) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: error.message }),
      };
    }
    if (error instanceof ForbiddenError) {
      return {
        statusCode: 403,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: error.message }),
      };
    }
    console.error('Failed to create check-in:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
