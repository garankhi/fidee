import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

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

    const insertSql = `
      INSERT INTO check_ins (user_id, place_id, candidate_id, media_id, gps_lat, gps_lng, gps_accuracy, caption, rating, visibility)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
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
      visibility,
    ]);
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
          id: result.rows[0].id,
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
    console.error('Failed to create check-in:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
