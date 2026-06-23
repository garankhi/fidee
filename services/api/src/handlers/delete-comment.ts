import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
};

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return { statusCode, headers: CORS_HEADERS, body: JSON.stringify(body) };
}

/**
 * DELETE /comments/{commentId} — Delete a comment (owner only).
 *
 * Child replies are cascade-deleted via the FK constraint.
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

    const commentId = event.pathParameters?.commentId;
    if (!commentId) {
      return jsonResponse(400, { error: 'Missing commentId' });
    }

    const result = await query(
      'DELETE FROM comments WHERE id = $1 AND user_id = $2',
      [commentId, userId]
    );

    if (result.rowCount === 0) {
      return jsonResponse(404, { error: 'Comment not found or not authorized' });
    }

    return jsonResponse(200, { success: true });
  } catch (error) {
    console.error('Error deleting comment:', error);
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
}
