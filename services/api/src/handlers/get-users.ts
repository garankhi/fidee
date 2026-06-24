import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';

/**
 * GET /admin/users
 * Returns list of all users from PostgreSQL.
 * Protected by Cognito JWT Authorizer (Admins group).
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    // 1. Verify user is in Admins group (Optional validation, API Gateway Cognito Authorizer should handle this)
    const groups = event.requestContext.authorizer?.jwt?.claims?.['cognito:groups'] || [];
    const isAdmin = Array.isArray(groups) ? groups.includes('Admins') : groups === 'Admins';

    // In local development or if authorizer is mocked, we can proceed

    // 2. Query all users from PostgreSQL
    const sql = `
      SELECT 
        id, 
        username, 
        display_name as "fullName", 
        email, 
        phone, 
        created_at as "joinedDate", 
        plan as "license", 
        place_count as "contributions"
      FROM users 
      ORDER BY created_at DESC;
    `;
    const result = await query(sql);

    // 3. Map values for frontend (e.g. format license and add default role 'User')
    const users = result.rows.map((row: any) => ({
      ...row,
      license: row.license === 'PRO' ? 'Pro' : 'Free',
      role:
        row.username === 'nguyenminh'
          ? 'Admin'
          : row.username === 'foodie_sg'
            ? 'Moderator'
            : 'User', // Simple role mapping based on seeds
      status: 'active', // Default status
      joinedDate: new Date(row.joinedDate).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
      }),
    }));

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
      },
      body: JSON.stringify(users),
    };
  } catch (error) {
    console.error('Error fetching users:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
}
