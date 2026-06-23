import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

/**
 * POST /comments — Create a comment on a candidate or check-in.
 *
 * Body:
 *   - targetType ('CANDIDATE' | 'CHECKIN')
 *   - targetId (uuid)
 *   - parentId (uuid, optional) — reply to another comment
 *   - content (string, 1-1000 chars)
 *
 * Replies are flattened to max 2 levels: if parentId points to a level-2
 * comment (one that already has a parent_id), we use its parent_id instead.
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

    const targetType = body.targetType ?? body.target_type;
    const targetId = body.targetId ?? body.target_id;
    const content = body.content;
    const requestedParentId = body.parentId ?? body.parent_id;
    let parentId = requestedParentId;
    let replyToUserId: string | null = null;

    // Validate targetType
    if (!targetType || !['CANDIDATE', 'CHECKIN'].includes(targetType)) {
      return jsonResponse(400, { error: 'targetType must be CANDIDATE or CHECKIN' });
    }

    // Validate targetId
    if (!targetId || typeof targetId !== 'string') {
      return jsonResponse(400, { error: 'targetId is required' });
    }

    // Validate content
    if (typeof content !== 'string' || content.trim().length === 0 || content.trim().length > 1000) {
      return jsonResponse(400, { error: 'content must be a string between 1 and 1000 characters' });
    }

    const trimmedContent = content.trim();

    // Handle parentId — flatten to max 2 levels
    if (parentId) {
      const parentResult = await query(
        'SELECT id, target_type, target_id, user_id, parent_id FROM comments WHERE id = $1',
        [parentId]
      );
      if (parentResult.rowCount === 0) {
        return jsonResponse(404, { error: 'Parent comment not found' });
      }
      const parentComment = parentResult.rows[0];
      if (
        String(parentComment.target_type) !== targetType ||
        String(parentComment.target_id) !== targetId
      ) {
        return jsonResponse(400, { error: 'Parent comment belongs to another target' });
      }
      replyToUserId = String(parentComment.user_id);
      // If parent is itself a reply (level-2), flatten to its parent
      if (parentComment.parent_id) {
        parentId = parentComment.parent_id;
      }
    }

    // INSERT the comment
    const insertSql = `
      INSERT INTO comments (target_type, target_id, user_id, parent_id, reply_to_user_id, content)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, target_type, target_id, parent_id, reply_to_user_id, content, user_id, created_at
    `;
    const insertResult = await query(insertSql, [
      targetType,
      targetId,
      userId,
      parentId || null,
      replyToUserId,
      trimmedContent,
    ]);
    const comment = insertResult.rows[0];

    // Fetch user info
    const userResult = await query(
      'SELECT display_name, username, avatar_url FROM users WHERE id = $1',
      [userId]
    );
    const user = userResult.rows[0];
    const replyToUserResult = replyToUserId
      ? await query('SELECT display_name FROM users WHERE id = $1', [replyToUserId])
      : null;
    const replyToUser = replyToUserResult?.rows[0];

    return jsonResponse(201, {
      id: comment.id,
      targetType: comment.target_type,
      targetId: comment.target_id,
      parentId: comment.parent_id,
      content: comment.content,
      userId: comment.user_id,
      userName: user?.display_name || null,
      userUsername: user?.username || null,
      userAvatar: user?.avatar_url || null,
      replyToUserId: comment.reply_to_user_id,
      replyToUserName: replyToUser?.display_name || null,
      createdAt: comment.created_at,
    });
  } catch (error) {
    console.error('Error creating comment:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
