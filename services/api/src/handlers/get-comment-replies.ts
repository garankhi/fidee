import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

/**
 * GET /comments/{commentId}/replies?cursor=&limit=
 *
 * Returns replies for a specific comment, ordered by created_at ASC.
 * Cursor-based pagination.
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    try {
      await extractAuth(event);
    } catch {
      return jsonResponse(401, { error: 'Unauthorized' });
    }

    const commentId = event.pathParameters?.commentId;
    if (!commentId) {
      return jsonResponse(400, { error: 'Missing commentId' });
    }

    const parentResult = await query('SELECT COALESCE(parent_id, id) AS id FROM comments WHERE id = $1', [
      commentId,
    ]);
    if (parentResult.rowCount === 0) {
      return jsonResponse(404, { error: 'Comment not found' });
    }
    const rootCommentId = parentResult.rows[0].id;

    const cursor = event.queryStringParameters?.cursor || null;
    let limit = parseInt(event.queryStringParameters?.limit || '20', 10);
    if (isNaN(limit) || limit <= 0) limit = 20;
    if (limit > 50) limit = 50;

    const params: any[] = [rootCommentId, limit + 1];
    let cursorFilter = '';
    if (cursor) {
      cursorFilter = 'AND c.created_at > $3';
      params.push(cursor);
    }

    const sql = `
      SELECT
        c.id,
        c.parent_id AS "parentId",
        c.content,
        c.user_id AS "userId",
        u.display_name AS "userName",
        u.username AS "userUsername",
        u.avatar_url AS "userAvatar",
        c.reply_to_user_id AS "replyToUserId",
        ru.display_name AS "replyToUserName",
        c.created_at AS "createdAt"
      FROM comments c
      JOIN users u ON u.id = c.user_id
      LEFT JOIN users ru ON ru.id = c.reply_to_user_id
      WHERE c.parent_id = $1
        ${cursorFilter}
      ORDER BY c.created_at ASC
      LIMIT $2
    `;

    const result = await query(sql, params);

    const hasMore = result.rows.length > limit;
    const data = hasMore ? result.rows.slice(0, limit) : result.rows;
    const nextCursor = hasMore ? data[data.length - 1].createdAt : null;

    return jsonResponse(200, {
      data,
      pagination: {
        nextCursor,
        hasMore,
      },
    });
  } catch (error) {
    console.error('Error fetching comment replies:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
