import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth } from '../middleware/auth';
import { query } from '../db/client';
import {
  enqueueFriendRealtimeEvent,
  FriendRealtimeEventInput,
  FriendRealtimeEventType,
} from '../realtime/friend-realtime-event';

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
    },
    body: JSON.stringify(body),
  };
}

function readTargetUserId(event: APIGatewayProxyEvent): string | null {
  const body = JSON.parse(event.body || '{}') as { targetUserId?: unknown };
  return typeof body.targetUserId === 'string' && body.targetUserId.trim().length > 0
    ? body.targetUserId.trim()
    : null;
}

function normalizeUsernameQuery(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const username = value.trim().toLowerCase();
  if (username.length < 2) return null;
  return username;
}

function canRequest(relationStatus: string): boolean {
  return relationStatus === 'NONE';
}

function relationDirection(
  relationStatus: string,
  initiatedBy: string | null | undefined,
  currentUserId: string,
): 'NONE' | 'OUTGOING' | 'INCOMING' {
  if (relationStatus !== 'PENDING') return 'NONE';
  return initiatedBy === currentUserId ? 'OUTGOING' : 'INCOMING';
}

interface ActorProfile {
  name: string;
  username: string | null;
  avatarUrl: string | null;
}

async function getActorProfile(userId: string, fallbackName: string): Promise<ActorProfile> {
  const result = await query(
    'SELECT display_name as name, username, avatar_url as "avatarUrl" FROM users WHERE id = $1',
    [userId],
  );
  const row = (result.rows[0] ?? {}) as {
    name?: string;
    username?: string | null;
    avatarUrl?: string | null;
  };
  return {
    name: row.name ?? fallbackName,
    username: row.username ?? null,
    avatarUrl: row.avatarUrl ?? null,
  };
}

function friendRealtimeEvent({
  type,
  targetUserId,
  actorUserId,
  relatedUserId,
  actor,
  createdAt,
}: {
  type: FriendRealtimeEventType;
  targetUserId: string;
  actorUserId: string;
  relatedUserId: string;
  actor: ActorProfile;
  createdAt: string;
}): FriendRealtimeEventInput {
  return {
    type,
    targetUserId,
    actorUserId,
    relatedUserId,
    actorName: actor.name,
    actorUsername: actor.username,
    actorAvatarUrl: actor.avatarUrl,
    createdAt,
  };
}

async function enqueueFriendRelationshipEvents(events: FriendRealtimeEventInput[]): Promise<void> {
  for (const event of events) {
    try {
      await enqueueFriendRealtimeEvent(event);
    } catch (error) {
      if ((error as { name?: string }).name !== 'ConditionalCheckFailedException') {
        console.error('enqueueFriendRealtimeEvent error', error);
      }
    }
  }
}

/**
 * GET /friends
 * Fetch all accepted, visible friends.
 */
export const getFriends = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);

    const sql = `
      SELECT u.id, u.display_name as name, u.username, u.avatar_url as "avatarUrl"
      FROM friendships f
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = $1
        AND f.status = 'ACCEPTED'
        AND COALESCE(f.is_hidden, FALSE) = FALSE
      ORDER BY u.display_name ASC
    `;
    const res = await query(sql, [auth.sub]);
    return jsonResponse(200, { friends: res.rows });
  } catch (error) {
    console.error('getFriends error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * GET /friends/search?username=minh
 * Search users by username prefix and include current relationship metadata.
 */
export const searchUsersByUsername = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const username = normalizeUsernameQuery(event.queryStringParameters?.username);
    if (!username) {
      return jsonResponse(400, { error: 'username query must be at least 2 characters' });
    }

    const res = await query(
      `
        SELECT
          u.id,
          u.display_name as name,
          u.username,
          u.avatar_url as "avatarUrl",
          f.status as "relationStatus",
          f.initiated_by as "initiatedBy"
        FROM users u
        LEFT JOIN friendships f ON f.user_id = $1 AND f.friend_id = u.id
        WHERE u.id <> $1
          AND u.username IS NOT NULL
          AND u.username LIKE $2
          AND COALESCE(f.status, 'NONE') <> 'BLOCKED'
        ORDER BY CASE WHEN u.username = $3 THEN 0 ELSE 1 END, u.username ASC
        LIMIT 20
      `,
      [auth.sub, `${username}%`, username],
    );

    const users = res.rows.map((row: any) => {
      const relationStatus = row.relationStatus ?? 'NONE';
      const direction = relationDirection(relationStatus, row.initiatedBy, auth.sub);
      return {
        id: row.id,
        name: row.name,
        username: row.username,
        avatarUrl: row.avatarUrl ?? null,
        relationStatus,
        relationDirection: direction,
        canRequest: canRequest(relationStatus),
        canCancelRequest: direction === 'OUTGOING',
        canAcceptRequest: direction === 'INCOMING',
      };
    });

    return jsonResponse(200, { users });
  } catch (error) {
    console.error('searchUsersByUsername error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * GET /friends/requests
 * Fetch all pending friend requests (received).
 */
export const getFriendRequests = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);

    const sql = `
      SELECT u.id, u.display_name as name, u.username, u.avatar_url as "avatarUrl"
      FROM friendships f
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = $1 AND f.status = 'PENDING' AND f.initiated_by != $1
      ORDER BY f.created_at DESC
    `;
    const res = await query(sql, [auth.sub]);
    return jsonResponse(200, { requests: res.rows });
  } catch (error) {
    console.error('getFriendRequests error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * GET /friends/requests/sent
 * Fetch all pending friend requests sent by the current user.
 */
export const getSentFriendRequests = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);

    const sql = `
      SELECT u.id, u.display_name as name, u.username, u.avatar_url as "avatarUrl"
      FROM friendships f
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = $1 AND f.status = 'PENDING' AND f.initiated_by = $1
      ORDER BY f.created_at DESC
    `;
    const res = await query(sql, [auth.sub]);
    return jsonResponse(200, { requests: res.rows });
  } catch (error) {
    console.error('getSentFriendRequests error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * POST /friends/request
 * Send a friend request to another user.
 */
export const sendFriendRequest = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = readTargetUserId(event);

    if (!targetUserId) {
      return jsonResponse(400, { error: 'targetUserId is required' });
    }

    if (auth.sub === targetUserId) {
      return jsonResponse(400, { error: 'Cannot friend yourself' });
    }

    const checkSql =
      'SELECT status, initiated_by FROM friendships WHERE user_id = $1 AND friend_id = $2';
    const check = await query(checkSql, [auth.sub, targetUserId]);

    if (check.rowCount && check.rowCount > 0) {
      const status = check.rows[0].status;
      return jsonResponse(400, {
        error: `Friend relationship already exists with status: ${status}`,
      });
    }

    const now = new Date().toISOString();

    await query('BEGIN');
    try {
      await query(
        `INSERT INTO friendships (user_id, friend_id, status, initiated_by, created_at)
         VALUES ($1, $2, 'PENDING', $3, $4)`,
        [auth.sub, targetUserId, auth.sub, now],
      );
      await query(
        `INSERT INTO friendships (user_id, friend_id, status, initiated_by, created_at)
         VALUES ($1, $2, 'PENDING', $3, $4)`,
        [targetUserId, auth.sub, auth.sub, now],
      );
      await query('COMMIT');
    } catch (e) {
      await query('ROLLBACK');
      throw e;
    }

    const actor = await getActorProfile(auth.sub, auth.username ?? 'Một người bạn');
    await enqueueFriendRelationshipEvents([
      friendRealtimeEvent({
        type: 'FRIEND_REQUEST_RECEIVED',
        targetUserId,
        actorUserId: auth.sub,
        relatedUserId: auth.sub,
        actor,
        createdAt: now,
      }),
    ]);

    return jsonResponse(200, { success: true, message: 'Friend request sent' });
  } catch (error) {
    console.error('sendFriendRequest error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * DELETE /friends/request
 * Cancel an outgoing pending friend request.
 */
export const cancelFriendRequest = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = readTargetUserId(event);

    if (!targetUserId) {
      return jsonResponse(400, { error: 'targetUserId is required' });
    }

    const now = new Date().toISOString();

    await query('BEGIN');
    try {
      const del1 = await query(
        `DELETE FROM friendships
         WHERE user_id = $1 AND friend_id = $2 AND status = 'PENDING' AND initiated_by = $1
         RETURNING status`,
        [auth.sub, targetUserId],
      );

      if (del1.rowCount === 0) {
        await query('ROLLBACK');
        return jsonResponse(400, { error: 'No outgoing request found' });
      }

      await query(
        `DELETE FROM friendships
         WHERE user_id = $2 AND friend_id = $1 AND status = 'PENDING' AND initiated_by = $1`,
        [auth.sub, targetUserId],
      );

      await query('COMMIT');
    } catch (e) {
      await query('ROLLBACK');
      throw e;
    }

    const actor = await getActorProfile(auth.sub, auth.username ?? 'Một người bạn');
    await enqueueFriendRelationshipEvents([
      friendRealtimeEvent({
        type: 'FRIEND_REQUEST_CANCELED',
        targetUserId,
        actorUserId: auth.sub,
        relatedUserId: auth.sub,
        actor,
        createdAt: now,
      }),
      friendRealtimeEvent({
        type: 'FRIEND_REQUEST_CANCELED',
        targetUserId: auth.sub,
        actorUserId: auth.sub,
        relatedUserId: targetUserId,
        actor,
        createdAt: now,
      }),
    ]);

    return jsonResponse(200, { success: true, message: 'Friend request canceled' });
  } catch (error) {
    console.error('cancelFriendRequest error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * POST /friends/accept
 * Accept a friend request.
 */
export const acceptFriend = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = readTargetUserId(event);

    if (!targetUserId) {
      return jsonResponse(400, { error: 'targetUserId is required' });
    }

    const now = new Date().toISOString();

    await query('BEGIN');
    try {
      const update1 = await query(
        `UPDATE friendships
         SET status = 'ACCEPTED', accepted_at = $3, is_hidden = FALSE
         WHERE user_id = $1 AND friend_id = $2 AND status = 'PENDING' AND initiated_by != $1
         RETURNING status`,
        [auth.sub, targetUserId, now],
      );

      if (update1.rowCount === 0) {
        await query('ROLLBACK');
        return jsonResponse(400, { error: 'No pending request found' });
      }

      await query(
        `UPDATE friendships
         SET status = 'ACCEPTED', accepted_at = $3, is_hidden = FALSE
         WHERE user_id = $2 AND friend_id = $1 AND status = 'PENDING'`,
        [auth.sub, targetUserId, now],
      );

      await query('UPDATE users SET friend_count = friend_count + 1 WHERE id = $1', [auth.sub]);
      await query('UPDATE users SET friend_count = friend_count + 1 WHERE id = $1', [targetUserId]);

      await query('COMMIT');
    } catch (e) {
      await query('ROLLBACK');
      throw e;
    }

    const actor = await getActorProfile(auth.sub, auth.username ?? 'Một người bạn');
    await enqueueFriendRelationshipEvents([
      friendRealtimeEvent({
        type: 'FRIEND_REQUEST_ACCEPTED',
        targetUserId,
        actorUserId: auth.sub,
        relatedUserId: auth.sub,
        actor,
        createdAt: now,
      }),
      friendRealtimeEvent({
        type: 'FRIEND_REQUEST_ACCEPTED',
        targetUserId: auth.sub,
        actorUserId: auth.sub,
        relatedUserId: targetUserId,
        actor,
        createdAt: now,
      }),
    ]);

    return jsonResponse(200, { success: true, message: 'Friend request accepted' });
  } catch (error) {
    console.error('acceptFriend error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * POST /friends/decline
 * Decline a friend request.
 */
export const declineFriend = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = readTargetUserId(event);

    if (!targetUserId) {
      return jsonResponse(400, { error: 'targetUserId is required' });
    }

    const now = new Date().toISOString();

    await query('BEGIN');
    try {
      const del1 = await query(
        `DELETE FROM friendships
         WHERE user_id = $1 AND friend_id = $2 AND status = 'PENDING' AND initiated_by != $1`,
        [auth.sub, targetUserId],
      );

      if (del1.rowCount === 0) {
        await query('ROLLBACK');
        return jsonResponse(400, { error: 'No pending request found' });
      }

      await query(
        `DELETE FROM friendships
         WHERE user_id = $2 AND friend_id = $1 AND status = 'PENDING'`,
        [auth.sub, targetUserId],
      );

      await query('COMMIT');
    } catch (e) {
      await query('ROLLBACK');
      throw e;
    }

    const actor = await getActorProfile(auth.sub, auth.username ?? 'Một người bạn');
    await enqueueFriendRelationshipEvents([
      friendRealtimeEvent({
        type: 'FRIEND_REQUEST_DECLINED',
        targetUserId,
        actorUserId: auth.sub,
        relatedUserId: auth.sub,
        actor,
        createdAt: now,
      }),
      friendRealtimeEvent({
        type: 'FRIEND_REQUEST_DECLINED',
        targetUserId: auth.sub,
        actorUserId: auth.sub,
        relatedUserId: targetUserId,
        actor,
        createdAt: now,
      }),
    ]);

    return jsonResponse(200, { success: true, message: 'Friend request declined' });
  } catch (error) {
    console.error('declineFriend error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * POST /friends/hide
 * Hide a friend from the current users friend list only.
 */
export const hideFriend = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = readTargetUserId(event);

    if (!targetUserId) {
      return jsonResponse(400, { error: 'targetUserId is required' });
    }

    const update = await query(
      `UPDATE friendships
       SET is_hidden = TRUE
       WHERE user_id = $1 AND friend_id = $2 AND status = 'ACCEPTED'
       RETURNING status`,
      [auth.sub, targetUserId],
    );

    if (update.rowCount === 0) {
      return jsonResponse(400, { error: 'Not currently friends' });
    }

    const actor = await getActorProfile(auth.sub, auth.username ?? 'Một người bạn');
    await enqueueFriendRelationshipEvents([
      friendRealtimeEvent({
        type: 'FRIENDSHIP_HIDDEN',
        targetUserId: auth.sub,
        actorUserId: auth.sub,
        relatedUserId: targetUserId,
        actor,
        createdAt: new Date().toISOString(),
      }),
    ]);

    return jsonResponse(200, { success: true, message: 'Friend hidden' });
  } catch (error) {
    console.error('hideFriend error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * POST /friends/unfriend
 * Remove friendship relationship.
 */
export const unfriend = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = readTargetUserId(event);

    if (!targetUserId) {
      return jsonResponse(400, { error: 'targetUserId is required' });
    }

    const now = new Date().toISOString();

    await query('BEGIN');
    try {
      const del1 = await query(
        `DELETE FROM friendships
         WHERE user_id = $1 AND friend_id = $2 AND status = 'ACCEPTED'
         RETURNING status`,
        [auth.sub, targetUserId],
      );

      if (del1.rowCount === 0) {
        await query('ROLLBACK');
        return jsonResponse(400, { error: 'Not currently friends' });
      }

      await query(
        `DELETE FROM friendships
         WHERE user_id = $2 AND friend_id = $1 AND status = 'ACCEPTED'`,
        [auth.sub, targetUserId],
      );

      await query('UPDATE users SET friend_count = GREATEST(0, friend_count - 1) WHERE id = $1', [
        auth.sub,
      ]);
      await query('UPDATE users SET friend_count = GREATEST(0, friend_count - 1) WHERE id = $1', [
        targetUserId,
      ]);

      await query('COMMIT');
    } catch (e) {
      await query('ROLLBACK');
      throw e;
    }

    const actor = await getActorProfile(auth.sub, auth.username ?? 'Một người bạn');
    await enqueueFriendRelationshipEvents([
      friendRealtimeEvent({
        type: 'FRIENDSHIP_REMOVED',
        targetUserId,
        actorUserId: auth.sub,
        relatedUserId: auth.sub,
        actor,
        createdAt: now,
      }),
      friendRealtimeEvent({
        type: 'FRIENDSHIP_REMOVED',
        targetUserId: auth.sub,
        actorUserId: auth.sub,
        relatedUserId: targetUserId,
        actor,
        createdAt: now,
      }),
    ]);

    return jsonResponse(200, { success: true, message: 'Unfriended successfully' });
  } catch (error) {
    console.error('unfriend error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};

/**
 * POST /friends/block
 * Block another user and remove accepted friendship visibility.
 */
export const blockFriend = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const auth = await extractAuth(event);
    const targetUserId = readTargetUserId(event);

    if (!targetUserId) {
      return jsonResponse(400, { error: 'targetUserId is required' });
    }

    if (auth.sub === targetUserId) {
      return jsonResponse(400, { error: 'Cannot block yourself' });
    }

    const now = new Date().toISOString();
    let shouldNotifyRelationshipChange = false;

    await query('BEGIN');
    try {
      const blockResult = await query(
        `WITH previous AS (
           SELECT status FROM friendships WHERE user_id = $1 AND friend_id = $2
         ), upsert AS (
           INSERT INTO friendships (user_id, friend_id, status, initiated_by, is_hidden, created_at)
           VALUES ($1, $2, 'BLOCKED', $1, FALSE, NOW())
           ON CONFLICT (user_id, friend_id) DO UPDATE
           SET status = 'BLOCKED', initiated_by = $1, is_hidden = FALSE, accepted_at = NULL
         )
         SELECT status FROM previous`,
        [auth.sub, targetUserId],
      );

      const reverseDelete = await query(
        `DELETE FROM friendships
      WHERE user_id = $2 AND friend_id = $1 AND status IN ('ACCEPTED', 'PENDING')`,
        [auth.sub, targetUserId],
      );

      const previousStatus = blockResult.rows[0]?.status;
      const wasAccepted = previousStatus === 'ACCEPTED';
      shouldNotifyRelationshipChange =
        previousStatus === 'ACCEPTED' ||
        previousStatus === 'PENDING' ||
        (reverseDelete.rowCount ?? 0) > 0;
      if (wasAccepted) {
        await query('UPDATE users SET friend_count = GREATEST(0, friend_count - 1) WHERE id = $1', [
          auth.sub,
        ]);
        await query('UPDATE users SET friend_count = GREATEST(0, friend_count - 1) WHERE id = $1', [
          targetUserId,
        ]);
      }

      await query('COMMIT');
    } catch (e) {
      await query('ROLLBACK');
      throw e;
    }

    if (shouldNotifyRelationshipChange) {
      const actor = await getActorProfile(auth.sub, auth.username ?? 'Một người bạn');
      await enqueueFriendRelationshipEvents([
        friendRealtimeEvent({
          type: 'FRIEND_BLOCKED',
          targetUserId,
          actorUserId: auth.sub,
          relatedUserId: auth.sub,
          actor,
          createdAt: now,
        }),
        friendRealtimeEvent({
          type: 'FRIEND_BLOCKED',
          targetUserId: auth.sub,
          actorUserId: auth.sub,
          relatedUserId: targetUserId,
          actor,
          createdAt: now,
        }),
      ]);
    }

    return jsonResponse(200, { success: true, message: 'Friend blocked' });
  } catch (error) {
    console.error('blockFriend error', error);
    return jsonResponse(500, { error: 'Internal server error' });
  }
};
