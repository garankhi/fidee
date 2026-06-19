import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

/**
 * POST /reviews — Create or update a review for a place/candidate.
 *
 * Body:
 *   - placeId (uuid, optional): target place
 *   - candidateId (uuid, optional): target candidate
 *   - rating (1-5, required)
 *   - content (string, optional, max 500)
 *   - visibility (FRIENDS|PRIVATE, optional, default FRIENDS)
 *
 * UPSERT: if user already reviewed this place, updates the existing review.
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    let userId: string;
    try {
      const auth = await extractAuth(event);
      userId = auth.sub;
    } catch {
      return jsonResponse(401, { error: 'Unauthorized' });
    }

    // Parse body
    if (!event.body) {
      return jsonResponse(400, { error: 'Request body is required' });
    }

    let body: any;
    try {
      body = JSON.parse(event.body);
    } catch {
      return jsonResponse(400, { error: 'Invalid JSON body' });
    }

    const { placeId, candidateId, rating, content, visibility, mediaIds } = body;

    // Validate target
    if (placeId && candidateId) {
      return jsonResponse(400, { error: 'Provide either placeId or candidateId, not both' });
    }
    if (!placeId && !candidateId) {
      return jsonResponse(400, { error: 'placeId or candidateId is required' });
    }

    // Validate rating
    if (typeof rating !== 'number' || !Number.isInteger(rating) || rating < 1 || rating > 5) {
      return jsonResponse(400, { error: 'rating must be an integer between 1 and 5' });
    }

    // Validate content
    if (content !== undefined && content !== null) {
      if (typeof content !== 'string') {
        return jsonResponse(400, { error: 'content must be a string' });
      }
      if (content.length > 500) {
        return jsonResponse(400, { error: 'content must be at most 500 characters' });
      }
    }

    // Validate mediaIds
    const validMediaIds: string[] = [];
    if (mediaIds !== undefined && mediaIds !== null) {
      if (!Array.isArray(mediaIds)) {
        return jsonResponse(400, { error: 'mediaIds must be an array of strings' });
      }
      if (mediaIds.length > 5) {
        return jsonResponse(400, { error: 'mediaIds can have at most 5 items' });
      }
      for (const id of mediaIds) {
        if (typeof id !== 'string' || id.trim().length === 0) {
          return jsonResponse(400, { error: 'Each mediaId must be a non-empty string' });
        }
        validMediaIds.push(id.trim());
      }
    }

    // Validate visibility
    const validVisibility = ['FRIENDS', 'PRIVATE'];
    const vis = visibility || 'FRIENDS';
    if (!validVisibility.includes(vis)) {
      return jsonResponse(400, { error: 'visibility must be FRIENDS or PRIVATE' });
    }

    // Verify target exists
    if (placeId) {
      const check = await query('SELECT id FROM places WHERE id = $1', [placeId]);
      if (check.rowCount === 0) {
        return jsonResponse(404, { error: 'Place not found' });
      }
    } else {
      const check = await query('SELECT id FROM place_candidates WHERE id = $1', [candidateId]);
      if (check.rowCount === 0) {
        return jsonResponse(404, { error: 'Place candidate not found' });
      }
    }

    // UPSERT review
    const reviewContent = content?.trim() || null;

    if (placeId) {
      const upsertSql = `
        INSERT INTO reviews (place_id, user_id, rating, content, visibility, media_ids)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (user_id, place_id) WHERE place_id IS NOT NULL
        DO UPDATE SET
          rating = EXCLUDED.rating,
          content = EXCLUDED.content,
          visibility = EXCLUDED.visibility,
          media_ids = EXCLUDED.media_ids,
          updated_at = NOW()
        RETURNING id, rating, content, media_ids, created_at, updated_at,
          (xmax = 0) AS is_new;
      `;
      const result = await query(upsertSql, [placeId, userId, rating, reviewContent, vis, validMediaIds]);
      const row = result.rows[0];
      const isNew = row.is_new;

      return jsonResponse(isNew ? 201 : 200, {
        status: 'success',
        data: {
          id: row.id,
          rating: row.rating,
          content: row.content,
          mediaIds: row.media_ids || [],
          createdAt: row.created_at,
          updatedAt: row.updated_at,
        },
      });
    } else {
      const upsertSql = `
        INSERT INTO reviews (candidate_id, user_id, rating, content, visibility, media_ids)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (user_id, candidate_id) WHERE candidate_id IS NOT NULL
        DO UPDATE SET
          rating = EXCLUDED.rating,
          content = EXCLUDED.content,
          visibility = EXCLUDED.visibility,
          media_ids = EXCLUDED.media_ids,
          updated_at = NOW()
        RETURNING id, rating, content, media_ids, created_at, updated_at,
          (xmax = 0) AS is_new;
      `;
      const result = await query(upsertSql, [candidateId, userId, rating, reviewContent, vis, validMediaIds]);
      const row = result.rows[0];
      const isNew = row.is_new;

      return jsonResponse(isNew ? 201 : 200, {
        status: 'success',
        data: {
          id: row.id,
          rating: row.rating,
          content: row.content,
          mediaIds: row.media_ids || [],
          createdAt: row.created_at,
          updatedAt: row.updated_at,
        },
      });
    }
  } catch (error) {
    console.error('Error creating review:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
