import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth, maskPhone, maskEmail } from '../middleware/auth';
import { query } from '../db/client';

type GamificationRow = {
  level: unknown;
  xp: unknown;
  coins: unknown;
  current_streak: unknown;
  title: unknown;
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
      `SELECT id, display_name, username, avatar_url, plan, created_at, friend_count, place_count, checkin_count 
       FROM users WHERE id = $1`,
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

    // 2. Fetch Gamification
    const gamificationResult = await query(
      'SELECT level, xp, coins, current_streak, title FROM user_gamification WHERE user_id = $1',
      [userId],
    );
    const gRow = (gamificationResult.rows[0] as GamificationRow | undefined) || {
      level: 1,
      xp: 0,
      coins: 0,
      current_streak: 0,
      title: null,
    };

    // 3. Fetch Badges
    const badgesResult = await query(
      `SELECT b.id, b.name, b.icon_url, ub.earned_at
       FROM user_badges ub
       JOIN badges b ON ub.badge_id = b.id
       WHERE ub.user_id = $1
       ORDER BY ub.earned_at DESC`,
      [userId],
    );
    const badges = badgesResult.rows.map((r: any) => ({
      id: r.id,
      name: r.name,
      icon: r.icon_url,
      earnedAt: r.earned_at,
    }));

    // 4. Fetch Challenges
    const challengesResult = await query(
      `SELECT c.id, c.title, c.target_value, uc.progress, uc.status
       FROM user_challenges uc
       JOIN challenges c ON uc.challenge_id = c.id
       WHERE uc.user_id = $1`,
      [userId],
    );
    const challenges = challengesResult.rows.map((r: any) => ({
      id: r.id,
      title: r.title,
      status: r.status,
      progress: r.progress,
      target: r.target_value,
    }));

    // 5. Fetch Top Friends (up to 5)
    const friendsResult = await query(
      `SELECT u.display_name, u.avatar_url 
       FROM friendships f
       JOIN users u ON f.friend_id = u.id
       WHERE f.user_id = $1 AND f.status = 'ACCEPTED'
       LIMIT 5`,
      [userId],
    );
    const topFriends = friendsResult.rows.map((r: any) => ({
      displayName: r.display_name,
      avatarUrl: r.avatar_url,
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

      displayName: userRow.display_name || 'User',
      username: userRow.username || null,
      avatarUrl: userRow.avatar_url || null,
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
