import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * POST /admin/places/candidates/{id}/approve
 *
 * Approve a place candidate:
 * 1. Copy data from place_candidates → places + place_settings (APPROVED)
 * 2. Delete from place_candidates
 * 3. Write audit log to place_moderation
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

    // 1. Fetch candidate
    const fetchSql = `
      SELECT * FROM place_candidates WHERE id = $1;
    `;
    const fetchResult = await query(fetchSql, [candidateId]);
    if (fetchResult.rows.length === 0) {
      return { statusCode: 404, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Candidate not found' }) };
    }
    const c = fetchResult.rows[0];

    // 2. Insert into places
    const insertPlaceSql = `
      INSERT INTO places (
        name, normalized_name, category, location, source, created_by,
        open_time, close_time, price_min, price_max, phone_number, description, metadata
      )
      VALUES ($1, $2, $3, $4, 'custom', $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING id;
    `;
    const placeResult = await query(insertPlaceSql, [
      c.name, c.normalized_name, c.category, c.location,
      c.created_by, c.open_time, c.close_time,
      c.price_min, c.price_max, c.phone_number, c.description,
      c.metadata || '{}',
    ]);
    const newPlaceId = placeResult.rows[0].id;

    // 3. Insert place_settings (APPROVED + PUBLIC)
    const insertSettingsSql = `
      INSERT INTO place_settings (place_id, visibility, status, updated_by)
      VALUES ($1, 'PUBLIC', 'APPROVED', $2);
    `;
    await query(insertSettingsSql, [newPlaceId, adminId]);

    // 4. Delete from place_candidates
    await query('DELETE FROM place_candidates WHERE id = $1;', [candidateId]);

    // 5. Audit log
    const auditSql = `
      INSERT INTO place_moderation (place_id, candidate_id, action, performed_by, note)
      VALUES ($1, $2, 'APPROVED', $3, 'Approved by admin');
    `;
    await query(auditSql, [newPlaceId, candidateId, adminId]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          action: 'approved',
          candidate_id: candidateId,
          new_place_id: newPlaceId,
          message: `Place "${c.name}" has been approved and is now publicly visible.`,
        },
      }),
    };
  } catch (error) {
    console.error('Error approving candidate:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
