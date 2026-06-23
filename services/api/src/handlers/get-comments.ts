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
 * GET /comments?targetType=CANDIDATE&targetId={uuid}&cursor=&limit=
 *
 * Returns top-level comments with replyCount and up to 3 most recent replies.
 * Cursor-based pagination on created_at DESC.
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    try {
      await extractAuth(event);
    } catch {
      return jsonResponse(401, { error: 'Unauthorized' });
    }

    const targetType =
      event.queryStringParameters?.targetType ?? event.queryStringParameters?.target_type;
    const targetId = event.queryStringParameters?.targetId ?? event.queryStringParameters?.target_id;
    const cursor = event.queryStringParameters?.cursor || null;

    let limit = parseInt(event.queryStringParameters?.limit || '20', 10);
    if (isNaN(limit) || limit <= 0) limit = 20;
    if (limit > 50) limit = 50;

    // Validate required params
    if (!targetType || !['CANDIDATE', 'CHECKIN'].includes(targetType)) {
      return jsonResponse(400, { error: 'targetType must be CANDIDATE or CHECKIN' });
    }
    if (!targetId) {
      return jsonResponse(400, { error: 'targetId is required' });
    }

    // Build query for top-level comments
    const params: any[] = [targetType, targetId, limit + 1];
    let cursorFilter = '';
    if (cursor) {
      cursorFilter = 'AND c.created_at < $4';
      params.push(cursor);
    }

    const sql = `
      SELECT
        c.id,
        c.target_type AS "targetType",
        c.target_id AS "targetId",
        c.content,
        c.user_id AS "userId",
        u.display_name AS "userName",
        u.username AS "userUsername",
        u.avatar_url AS "userAvatar",
        NULL AS "parentId",
        c.created_at AS "createdAt",
        (SELECT COUNT(*)::integer FROM comments r WHERE r.parent_id = c.id) AS "replyCount"
      FROM comments c
      JOIN users u ON u.id = c.user_id
      WHERE c.target_type = $1
        AND c.target_id = $2
        AND c.parent_id IS NULL
        ${cursorFilter}
      ORDER BY c.created_at DESC
      LIMIT $3
    `;

    const result = await query(sql, params);

    const hasMore = result.rows.length > limit;
    const topComments = hasMore ? result.rows.slice(0, limit) : result.rows;
    const nextCursor = hasMore ? topComments[topComments.length - 1].createdAt : null;

    // Fetch up to 3 most recent replies for each top-level comment
    const commentIds = topComments.map((c: any) => c.id);
    let repliesMap: Record<string, any[]> = {};

    if (commentIds.length > 0) {
      const repliesSql = `
        SELECT
          r.id,
          r.parent_id AS "parentId",
          r.content,
          r.user_id AS "userId",
          u.display_name AS "userName",
          u.username AS "userUsername",
          u.avatar_url AS "userAvatar",
          r.created_at AS "createdAt",
          r.reply_to_user_id AS "replyToUserId",
          pu.display_name AS "replyToUserName"
        FROM (
          SELECT *,
            ROW_NUMBER() OVER (PARTITION BY parent_id ORDER BY created_at DESC) AS rn
          FROM comments
          WHERE parent_id = ANY($1)
        ) r
        JOIN users u ON u.id = r.user_id
        LEFT JOIN users pu ON pu.id = r.reply_to_user_id
        WHERE r.rn <= 3
        ORDER BY r.parent_id, r.created_at ASC
      `;
      const repliesResult = await query(repliesSql, [commentIds]);

      for (const reply of repliesResult.rows) {
        const pid = String(reply.parentId);
        if (!repliesMap[pid]) repliesMap[pid] = [];
        // Only include replyToUser if different from the top-level comment author
        const replyData: any = {
          id: reply.id,
          parentId: reply.parentId,
          content: reply.content,
          userId: reply.userId,
          userName: reply.userName,
          userUsername: reply.userUsername,
          userAvatar: reply.userAvatar,
          createdAt: reply.createdAt,
        };
        replyData.replyToUserId = reply.replyToUserId;
        replyData.replyToUserName = reply.replyToUserName;
        repliesMap[pid].push(replyData);
      }
    }

    // Assemble response
    const data = topComments.map((c: any) => ({
      id: c.id,
      targetType: c.targetType,
      targetId: c.targetId,
      content: c.content,
      userId: c.userId,
      userName: c.userName,
      userUsername: c.userUsername,
      userAvatar: c.userAvatar,
      parentId: c.parentId,
      createdAt: c.createdAt,
      replyCount: c.replyCount,
      replies: repliesMap[c.id] || [],
    }));

    return jsonResponse(200, {
      data,
      pagination: {
        nextCursor,
        hasMore,
      },
    });
  } catch (error) {
    console.error('Error fetching comments:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
