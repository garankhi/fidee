import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth, maskPhone, maskEmail } from '../middleware/auth';
import { query } from '../db/client';

type TopFriendRow = {
  display_name: string;
  avatar_url: string | null;
};

function numberValue(value: unknown, fallback = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * GET /profile — returns the authenticated user's profile from JWT claims & DB.
 * Protected by Cognito JWT Authorizer.
 */
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const userId = auth.sub;

    // 1. Fetch user core info & stats
    const userResult = await query(
      `SELECT
         id,
         display_name,
         family_name,
         given_name,
         username,
         avatar_url,
         bio,
         plan,
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

    // Gamification, Badges, Challenges skipped (tables not available in prod).
    // add when tables are migrated.
    const gRow = {
      level: 1,
      xp: 0,
      coins: 0,
      current_streak: 0,
      title: null,
    };
    const badges: unknown[] = [];
    const challenges: unknown[] = [];

    // 5. Fetch Top Friends (up to 5)
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
    const title = typeof gRow.title === 'string' ? gRow.title : null;

    // Calculate nextLevelXp logic (simple formula: level * 100)
    const nextLevelXp = level * 100;

    const responseBody = {
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
      plan: userRow.plan || 'FREE',
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
    };

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify(responseBody),
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unauthorized';
    const statusCode = message.startsWith('Forbidden') ? 403 : 401;

    return {
      statusCode,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: message }),
    };
  }
};
