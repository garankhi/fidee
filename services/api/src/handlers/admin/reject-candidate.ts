import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * POST /admin/places/candidates/{id}/reject
 *
 * Reject a place candidate:
 * 1. Update status to REJECTED with reason (keep record for user visibility)
 * 2. Write audit log to place_moderation
 *
 * Body: { "reason": "..." } (required)
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const adminId = event.requestContext.authorizer?.jwt?.claims?.sub
      || event.requestContext.authorizer?.claims?.sub;
    if (!adminId) {
      return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
    }

    const candidateId = event.pathParameters?.id;
    if (!candidateId) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Missing candidate id' }) };
    }

    const body = JSON.parse(event.body || '{}');
    const reason = body.reason;
    if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Rejection reason is required' }),
      };
    }

    // 1. Verify candidate exists
    const fetchSql = 'SELECT id, name, created_by FROM place_candidates WHERE id = $1;';
    const fetchResult = await query(fetchSql, [candidateId]);
    if (fetchResult.rows.length === 0) {
      return { statusCode: 404, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Candidate not found' }) };
    }
    const candidateName = fetchResult.rows[0].name;

    // 2. Update status to REJECTED (keep record so user can see why)
    const updateSql = `
      UPDATE place_candidates
      SET status = 'REJECTED',
          rejection_reason = $1,
          reviewed_by = $2,
          reviewed_at = NOW()
      WHERE id = $3;
    `;
    await query(updateSql, [reason.trim(), adminId, candidateId]);

    // 3. Audit log
    const auditSql = `
      INSERT INTO place_moderation (place_id, candidate_id, action, performed_by, note)
      VALUES (NULL, $1, 'REJECTED', $2, $3);
    `;
    await query(auditSql, [candidateId, adminId, reason.trim()]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          action: 'rejected',
          candidate_id: candidateId,
          reason: reason.trim(),
          message: `Place "${candidateName}" has been rejected.`,
        },
      }),
    };
  } catch (error) {
    console.error('Error rejecting candidate:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
