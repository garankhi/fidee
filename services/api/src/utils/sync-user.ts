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

  const displayName = [givenName, familyName].filter(Boolean).join(' ') || email || 'User';
  const username = preferredUsername || null;

  // 1. Sync to PostgreSQL
  const sql = `
    INSERT INTO users (id, display_name, username, email, phone, avatar_url, plan)
    VALUES ($1, $2, $3, $4, $5, $6, 'FREE')
    ON CONFLICT (id) DO UPDATE
    SET 
      display_name = EXCLUDED.display_name,
      username = COALESCE(EXCLUDED.username, users.username),
      email = EXCLUDED.email,
      phone = COALESCE(EXCLUDED.phone, users.phone),
      avatar_url = COALESCE(EXCLUDED.avatar_url, users.avatar_url)
    WHERE users.display_name != EXCLUDED.display_name
       OR (users.username IS NULL AND EXCLUDED.username IS NOT NULL)
       OR users.email != EXCLUDED.email
       OR (users.phone IS NULL AND EXCLUDED.phone IS NOT NULL)
       OR (users.avatar_url IS NULL AND EXCLUDED.avatar_url IS NOT NULL)
       OR users.avatar_url != EXCLUDED.avatar_url;
  `;
  
  try {
    await query(sql, [sub, displayName, username, email || null, phone || null, picture || null]);
  } catch (err) {
    console.error(`[Sync User] PostgreSQL upsert failed for sub ${sub}:`, err);
    throw err;
  }

  // 2. Sync to DynamoDB user-profiles table
  const userProfilesTable = process.env.USER_PROFILES_TABLE;
  if (userProfilesTable) {
    try {
      await dynamoClient.send(
        new UpdateCommand({
          TableName: userProfilesTable,
          Key: { userId: sub },
          UpdateExpression: 'SET displayName = :displayName, email = :email, updatedAt = :updatedAt, #plan = if_not_exists(#plan, :defaultPlan)',
          ExpressionAttributeNames: {
            '#plan': 'plan',
          },
          ExpressionAttributeValues: {
            ':displayName': displayName,
            ':email': email || '',
            ':updatedAt': new Date().toISOString(),
            ':defaultPlan': 'FREE',
          },
        })
      );
    } catch (err) {
      console.error(`[Sync User] DynamoDB upsert failed for sub ${sub}:`, err);
    }
  }
}
