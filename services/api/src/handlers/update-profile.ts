import {
  AdminUpdateUserAttributesCommand,
  CognitoIdentityProviderClient,
} from '@aws-sdk/client-cognito-identity-provider';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';

const cognitoClient = new CognitoIdentityProviderClient({});
const USERNAME_PATTERN = /^[a-z0-9._]{3,30}$/;
const DEFAULT_COGNITO_MIRROR_TIMEOUT_MS = 1_500;

type ProfileRow = {
  id: string;
  display_name: string;
  username: string | null;
  avatar_url: string | null;
  bio: string | null;
  plan: string;
  created_at: string | Date;
};

type UpdateProfileBody = {
  firstName?: unknown;
  lastName?: unknown;
  username?: unknown;
  bio?: unknown;
};

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === '23505'
  );
}

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,PATCH,OPTIONS',
    },
    body: JSON.stringify(body),
  };
}

function parseJsonBody(event: APIGatewayProxyEvent): UpdateProfileBody {
  if (!event.body) {
    throw new ValidationError('Request body is required');
  }

  try {
    return JSON.parse(event.body) as UpdateProfileBody;
  } catch {
    throw new ValidationError('Request body must be valid JSON');
  }
}

class ValidationError extends Error {}

function readRequiredString(body: UpdateProfileBody, key: keyof UpdateProfileBody): string {
  const value = body[key];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ValidationError(`${key} is required`);
  }
  return value.trim();
}

function normalizeUsername(value: string): string {
  const username = value.trim().toLowerCase();
  if (!USERNAME_PATTERN.test(username)) {
    throw new ValidationError(
      'username must be 3-30 chars and contain only lowercase letters, numbers, dots, or underscores',
    );
  }
  return username;
}

function readOptionalBio(body: UpdateProfileBody): string | null {
  if (body.bio == null) return null;
  if (typeof body.bio !== 'string') {
    throw new ValidationError('bio must be a string');
  }

  const bio = body.bio.trim();
  if (bio.length > 160) {
    throw new ValidationError('bio must be 160 characters or less');
  }

  return bio.length === 0 ? null : bio;
}

function toProfileResponse(row: ProfileRow): Record<string, unknown> {
  const createdAt =
    row.created_at instanceof Date
      ? row.created_at.toISOString()
      : new Date(row.created_at).toISOString();

  return {
    id: row.id,
    displayName: row.display_name,
    username: row.username,
    avatarUrl: row.avatar_url,
    bio: row.bio,
    plan: row.plan,
    createdAt,
  };
}

async function mirrorCognitoProfile(
  cognitoUsername: string,
  firstName: string,
  lastName: string,
  username: string,
): Promise<void> {
  const userPoolId = process.env.COGNITO_USER_POOL_ID;
  if (!userPoolId) return;

  const configuredTimeout = Number.parseInt(
    process.env.COGNITO_PROFILE_MIRROR_TIMEOUT_MS ?? '',
    10,
  );
  const timeoutMs = Number.isFinite(configuredTimeout)
    ? Math.max(1, configuredTimeout)
    : DEFAULT_COGNITO_MIRROR_TIMEOUT_MS;

  const abortController = new AbortController();
  const timeout = setTimeout(() => abortController.abort(), timeoutMs);

  try {
    await cognitoClient.send(
      new AdminUpdateUserAttributesCommand({
        UserPoolId: userPoolId,
        Username: cognitoUsername,
        UserAttributes: [
          { Name: 'given_name', Value: firstName },
          { Name: 'family_name', Value: lastName },
          { Name: 'preferred_username', Value: username },
        ],
      }),
      { abortSignal: abortController.signal },
    );
  } catch (error) {
    console.error(
      `[Update Profile] Failed to mirror Cognito attributes for ${cognitoUsername}`,
      error,
    );
  } finally {
    clearTimeout(timeout);
  }
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const body = parseJsonBody(event);
    const firstName = readRequiredString(body, 'firstName');
    const lastName = readRequiredString(body, 'lastName');
    const username = normalizeUsername(readRequiredString(body, 'username'));
    const bio = readOptionalBio(body);
    const displayName = [firstName, lastName].join(' ');

    const updateResult = await query<ProfileRow>(
      `
        INSERT INTO users (id, display_name, username, email, phone, bio, plan)
        SELECT $1, $2, $3, $4, $5, $6, 'FREE'
        WHERE NOT EXISTS (
          SELECT 1 FROM users
          WHERE username = $3 AND id <> $1
        )
        ON CONFLICT (id) DO UPDATE
        SET display_name = EXCLUDED.display_name,
            username = EXCLUDED.username,
            email = COALESCE(EXCLUDED.email, users.email),
            phone = COALESCE(EXCLUDED.phone, users.phone),
            bio = EXCLUDED.bio
        WHERE NOT EXISTS (
          SELECT 1 FROM users
          WHERE username = EXCLUDED.username AND id <> users.id
        )
        RETURNING id, display_name, username, avatar_url, bio, plan, created_at;
      `,
      [auth.sub, displayName, username, auth.email ?? null, auth.phone ?? null, bio],
    );

    if (updateResult.rowCount === 0) {
      return jsonResponse(409, { error: 'Username already taken', code: 'USERNAME_TAKEN' });
    }

    await mirrorCognitoProfile(auth.username ?? auth.sub, firstName, lastName, username);

    return jsonResponse(200, {
      profile: toProfileResponse(updateResult.rows[0]),
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

    if (isUniqueViolation(error)) {
      return jsonResponse(409, { error: 'Username already taken', code: 'USERNAME_TAKEN' });
    }

    console.error('Failed to update profile', error);
    return jsonResponse(500, { error: 'Internal server error', code: 'INTERNAL_ERROR' });
  }
};
