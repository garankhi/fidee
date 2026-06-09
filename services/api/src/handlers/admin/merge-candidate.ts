import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../../db/client';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * POST /admin/places/candidates/{id}/merge
 *
 * Merge a candidate into an existing approved place:
 * 1. Re-point any check-ins linked to this candidate to the target place
 * 2. Delete candidate from place_candidates
 * 3. Write audit log with merge info
 *
 * Body: { "target_place_id": "uuid" } (required)
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

    // Parse body
    const body = JSON.parse(event.body || '{}');
    const targetPlaceId = body.target_place_id;
    if (!targetPlaceId) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'target_place_id is required' }),
      };
    }

    // 1. Verify candidate exists
    const fetchCandidateSql = 'SELECT id, name, created_by FROM place_candidates WHERE id = $1;';
    const candidateResult = await query(fetchCandidateSql, [candidateId]);
    if (candidateResult.rows.length === 0) {
      return { statusCode: 404, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Candidate not found' }) };
    }
    const candidateName = candidateResult.rows[0].name;

    // 2. Verify target place exists and is APPROVED
    const fetchTargetSql = `
      SELECT p.id, p.name
      FROM places p
      JOIN place_settings ps ON ps.place_id = p.id
      WHERE p.id = $1 AND ps.status = 'APPROVED';
    `;
    const targetResult = await query(fetchTargetSql, [targetPlaceId]);
    if (targetResult.rows.length === 0) {
      return {
        statusCode: 404,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Target place not found or not approved' }),
      };
    }
    const targetName = targetResult.rows[0].name;

    // 3. Re-point check-ins: find check-ins by the candidate creator
    //    near the candidate location and update their place_id
    //    (This is a best-effort merge; in practice there may be 0 check-ins)
    const candidateLocSql = 'SELECT ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng FROM place_candidates WHERE id = $1;';
    const locResult = await query(candidateLocSql, [candidateId]);
    if (locResult.rows.length > 0) {
      const { lat, lng } = locResult.rows[0];
      const updateCheckinsSql = `
        UPDATE check_ins
        SET place_id = $1
        WHERE user_id = $2
          AND ST_DWithin(
            ST_MakePoint(gps_lng, gps_lat)::geography,
            ST_MakePoint($3, $4)::geography,
            100
          );
      `;
      await query(updateCheckinsSql, [
        targetPlaceId,
        candidateResult.rows[0].created_by,
        lng, lat,
      ]);
    }

    // 4. Delete candidate
    await query('DELETE FROM place_candidates WHERE id = $1;', [candidateId]);

    // 5. Audit log
    const auditSql = `
      INSERT INTO place_moderation (place_id, candidate_id, action, merged_into_place_id, performed_by, note)
      VALUES ($1, $2, 'MERGED', $1, $3, $4);
    `;
    await query(auditSql, [
      targetPlaceId,
      candidateId,
      adminId,
      `Merged "${candidateName}" into "${targetName}"`,
    ]);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        status: 'success',
        data: {
          action: 'merged',
          candidate_id: candidateId,
          merged_into: targetPlaceId,
          message: `"${candidateName}" has been merged into "${targetName}".`,
        },
      }),
    };
  } catch (error) {
    console.error('Error merging candidate:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
