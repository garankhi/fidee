import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { query } from '../db/client';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export interface SyncUserParams {
  sub: string;
  email?: string;
  phone?: string;
  givenName?: string;
  familyName?: string;
  preferredUsername?: string;
  picture?: string;
}

/**
 * Automates user profiles upsert to both PostgreSQL and DynamoDB.
 * Updates fields only when they change to reduce write overhead.
 */
export async function syncUserToDatabases({
  sub,
  email,
  phone,
  givenName,
  familyName,
  preferredUsername,
  picture,
}: SyncUserParams): Promise<void> {
  // Skip DB syncing in test environment
  if (process.env.NODE_ENV === 'test' || process.env.VITEST) {
    return;
  }

  const normalizedFamilyName = familyName?.trim() || null;
  const normalizedGivenName = givenName?.trim() || null;
  const displayNameFromClaims = [normalizedFamilyName, normalizedGivenName]
    .filter(Boolean)
    .join(' ');
  const displayNameForInsert = displayNameFromClaims || email || 'User';
  const displayNameForUpdate = displayNameFromClaims || null;
  const username = preferredUsername?.trim().toLowerCase() || null;

  // 1. Sync to PostgreSQL
  const sql = `
    INSERT INTO users (
      id,
      display_name,
      family_name,
      given_name,
      username,
      email,
      phone,
      avatar_url,
      plan
    )
    SELECT
      $1,
      $2,
      $3,
      $4,
      CASE
        WHEN $5::text IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM users WHERE username = $5)
        THEN $5
        ELSE NULL
      END,
      $6,
      $7,
      $8,
      'FREE'
    ON CONFLICT (id) DO UPDATE
    SET
      family_name = COALESCE(users.family_name, EXCLUDED.family_name),
      given_name = COALESCE(users.given_name, EXCLUDED.given_name),
      display_name = CASE
        WHEN users.family_name IS NULL
          AND users.given_name IS NULL
          AND (EXCLUDED.family_name IS NOT NULL OR EXCLUDED.given_name IS NOT NULL)
        THEN EXCLUDED.display_name
        ELSE users.display_name
      END,
      username = CASE
        WHEN users.username IS NULL AND EXCLUDED.username IS NOT NULL
        THEN EXCLUDED.username
        ELSE users.username
      END,
      email = EXCLUDED.email,
      phone = COALESCE(EXCLUDED.phone, users.phone),
      avatar_url = COALESCE(EXCLUDED.avatar_url, users.avatar_url)
    WHERE (users.family_name IS NULL AND EXCLUDED.family_name IS NOT NULL)
       OR (users.given_name IS NULL AND EXCLUDED.given_name IS NOT NULL)
       OR (users.username IS NULL AND EXCLUDED.username IS NOT NULL)
       OR users.email IS DISTINCT FROM EXCLUDED.email
       OR (users.phone IS NULL AND EXCLUDED.phone IS NOT NULL)
       OR (users.avatar_url IS NULL AND EXCLUDED.avatar_url IS NOT NULL)
       OR users.avatar_url IS DISTINCT FROM EXCLUDED.avatar_url;
  `;

  const params = [
    sub,
    displayNameForInsert,
    normalizedFamilyName,
    normalizedGivenName,
    username,
    email || null,
    phone || null,
    picture || null,
  ];

  try {
    await query(sql, params);
  } catch (err) {
    if (isUniqueViolation(err)) {
      console.warn(`[Sync User] Skipped duplicate username sync for sub ${sub}`);
      const retryParams = [...params];
      retryParams[4] = null;
      await query(sql, retryParams);
      return;
    }
    console.error(`[Sync User] PostgreSQL upsert failed for sub ${sub}:`, err);
    throw err;
  }

  // 2. Sync to DynamoDB user-profiles table
  const userProfilesTable = process.env.USER_PROFILES_TABLE;
  if (userProfilesTable) {
    try {
      const updateExpressionParts = [
        'email = :email',
        'updatedAt = :updatedAt',
        '#plan = if_not_exists(#plan, :defaultPlan)',
      ];
      const expressionAttributeValues: Record<string, string> = {
        ':email': email || '',
        ':updatedAt': new Date().toISOString(),
        ':defaultPlan': 'FREE',
      };

      if (displayNameForUpdate) {
        updateExpressionParts.unshift('displayName = :displayName');
        expressionAttributeValues[':displayName'] = displayNameForUpdate;
      }

      await dynamoClient.send(
        new UpdateCommand({
          TableName: userProfilesTable,
          Key: { userId: sub },
          UpdateExpression: `SET ${updateExpressionParts.join(', ')}`,
          ExpressionAttributeNames: {
            '#plan': 'plan',
          },
          ExpressionAttributeValues: expressionAttributeValues,
        }),
      );
    } catch (err) {
      console.error(`[Sync User] DynamoDB upsert failed for sub ${sub}:`, err);
    }
  }
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === '23505'
  );
}
