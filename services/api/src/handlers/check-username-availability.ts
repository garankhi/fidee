import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const USERNAME_PATTERN = /^[a-z0-9._]{3,30}$/;

class ValidationError extends Error {}

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,OPTIONS',
    },
    body: JSON.stringify(body),
  };
}

function normalizeUsername(value: unknown): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ValidationError('username is required');
  }

  const username = value.trim().toLowerCase();
  if (!USERNAME_PATTERN.test(username)) {
    throw new ValidationError(
      'username must be 3-30 chars and contain only lowercase letters, numbers, dots, or underscores',
    );
  }

  return username;
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const username = normalizeUsername(event.queryStringParameters?.username);

    const existingUser = await query<{ id: string }>(
      `
        SELECT id
        FROM users
        WHERE username = $1
          AND id <> $2
        LIMIT 1;
      `,
      [username, auth.sub],
    );

    const available = existingUser.rowCount === 0;

    return jsonResponse(200, {
      username,
      available,
      reason: available ? null : 'USERNAME_TAKEN',
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return jsonResponse(400, { error: error.message, code: 'VALIDATION_ERROR' });
    }

    if (error instanceof Error && error.message.startsWith('Missing auth context')) {
      return jsonResponse(401, { error: error.message, code: 'UNAUTHORIZED' });
    }

    if (error instanceof Error && error.message.startsWith('Forbidden')) {
      return jsonResponse(403, { error: error.message, code: 'FORBIDDEN' });
    }

    console.error('Failed to check username availability', error);
    return jsonResponse(500, { error: 'Internal server error', code: 'INTERNAL_ERROR' });
  }
};
