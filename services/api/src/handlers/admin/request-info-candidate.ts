import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * POST /admin/places/candidates/{id}/request-info
 *
 * Admin requests more evidence from the user.
 * Sets status to NEEDS_MORE_INFO with a note explaining what's needed.
 *
 * Body: { "note": "..." } (required)
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
    const note = body.note;
    if (!note || typeof note !== 'string' || note.trim().length === 0) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Note is required to explain what info is needed' }),
      };
    }

    // 1. Verify candidate exists
    const fetchSql = `SELECT id, name FROM place_candidates WHERE id = $1;`;
    const fetchResult = await query(fetchSql, [candidateId]);
    if (fetchResult.rows.length === 0) {
      return { statusCode: 404, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Candidate not found' }) };
    }
    const candidateName = fetchResult.rows[0].name;

    // 2. Update status
    const updateSql = `
      UPDATE place_candidates
      SET status = 'NEEDS_MORE_INFO',
          rejection_reason = $1,
          reviewed_by = $2,
          reviewed_at = NOW()
      WHERE id = $3;
    `;
    await query(updateSql, [note.trim(), adminId, candidateId]);

    // 3. Audit log
    const auditSql = `
      INSERT INTO place_moderation (place_id, candidate_id, action, performed_by, note)
      VALUES (NULL, $1, 'REQUEST_MORE_INFO', $2, $3);
    `;
    await query(auditSql, [candidateId, adminId, note.trim()]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          action: 'request_more_info',
          candidate_id: candidateId,
          note: note.trim(),
          message: `Requested more info for "${candidateName}".`,
        },
      }),
    };
  } catch (error) {
    console.error('Error requesting more info:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
