import type {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth, maskEmail, maskPhone } from '../middleware/auth';
import {
  getUserPlan,
  type UserPlan,
} from '../repositories/user-profiles';

type TopFriendRow = {
  display_name: string;
  avatar_url: string | null;
};

interface GetProfileDeps {
  getPlan: (userId: string) => Promise<UserPlan>;
}

function numberValue(value: unknown, fallback = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function defaultDeps(): GetProfileDeps {
  const tableName = process.env.USER_PROFILES_TABLE;
  if (!tableName) {
    throw new Error('USER_PROFILES_TABLE is required');
  }
  return {
    getPlan: (userId) => getUserPlan(userId, tableName),
  };
}

function errorResponse(
  statusCode: number,
  message: string,
): APIGatewayProxyResult {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ error: message }),
  };
}

export function createGetProfileHandler(deps: GetProfileDeps) {
  return async (
    event: APIGatewayProxyEvent,
  ): Promise<APIGatewayProxyResult> => {
    try {
      const auth = await extractAuth(event);
      const userId = auth.sub;

      const userResult = await query(
        `SELECT
           id,
           display_name,
           family_name,
           given_name,
           username,
           avatar_url,
           bio,
           created_at,
           friend_count,
           place_count,
           checkin_count
         FROM users
         WHERE id = $1`,
        [userId],
      );

      if (!userResult || userResult.rowCount === 0) {
        return {
          statusCode: 404,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ error: 'User not found' }),
        };
      }
      const userRow = userResult.rows[0];
      const plan = await deps.getPlan(userId);

      const gRow = {
        level: 1,
        xp: 0,
        coins: 0,
        current_streak: 0,
        title: null as string | null,
      };
      const badges: unknown[] = [];
      const challenges: unknown[] = [];

      const friendsResult = await query<TopFriendRow>(
        `SELECT u.display_name, u.avatar_url
         FROM friendships f
         JOIN users u ON f.friend_id = u.id
         WHERE f.user_id = $1 AND f.status = 'ACCEPTED'
         LIMIT 5`,
        [userId],
      );
      const topFriends = friendsResult.rows.map((row) => ({
        displayName: row.display_name,
        avatarUrl: row.avatar_url,
      }));

      const level = numberValue(gRow.level, 1);
      const xp = numberValue(gRow.xp);
      const coins = numberValue(gRow.coins);
      const streak = numberValue(gRow.current_streak);
      const title =
        typeof gRow.title === 'string' ? gRow.title : null;
      const nextLevelXp = level * 100;

      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({
          sub: userId,
          phone: auth.phone ? maskPhone(auth.phone) : null,
          email: auth.email ? maskEmail(auth.email) : null,
          groups: auth.groups,
          firstName: userRow.family_name || null,
          lastName: userRow.given_name || null,
          displayName: userRow.display_name || 'User',
          username: userRow.username || null,
          avatarUrl: userRow.avatar_url || null,
          bio: userRow.bio || null,
          plan,
          createdAt: userRow.created_at,
          title,
          gamification: {
            level,
            xp,
            nextLevelXp,
            coins,
            streak,
          },
          stats: {
            spots: Number(userRow.place_count) || 0,
            friends: Number(userRow.friend_count) || 0,
          },
          badges,
          challenges,
          topFriends,
        }),
      };
    } catch (error) {
      if (
        error instanceof Error &&
        error.message.startsWith('Missing auth context')
      ) {
        return errorResponse(401, error.message);
      }

      if (
        error instanceof Error &&
        error.message.startsWith('Forbidden')
      ) {
        return errorResponse(403, error.message);
      }

      console.error('Get profile failed');
      return errorResponse(500, 'Internal server error');
    }
  };
}

export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    return await createGetProfileHandler(defaultDeps())(event);
  } catch {
    console.error('Get profile configuration failed');
    return errorResponse(500, 'Internal server error');
  }
};
