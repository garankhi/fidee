import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery, mockExtractAuth, mockEnqueueFriendRealtimeEvent } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockExtractAuth: vi.fn(),
  mockEnqueueFriendRealtimeEvent: vi.fn(),
}));

vi.mock('../db/client', () => ({
  query: mockQuery,
}));

vi.mock('../middleware/auth', () => ({
  extractAuth: mockExtractAuth,
}));

vi.mock('../realtime/friend-realtime-event', () => ({
  enqueueFriendRealtimeEvent: mockEnqueueFriendRealtimeEvent,
}));

import {
  acceptFriend,
  blockFriend,
  cancelFriendRequest,
  declineFriend,
  getSentFriendRequests,
  hideFriend,
  searchUsersByUsername,
  sendFriendRequest,
  unfriend,
} from './friends-handlers';

const mockEvent = ({
  body,
  httpMethod,
  queryStringParameters,
}: {
  body?: Record<string, unknown> | null;
  httpMethod?: string;
  queryStringParameters?: Record<string, string> | null;
} = {}): APIGatewayProxyEvent =>
  ({
    requestContext: { authorizer: { claims: { sub: 'user-1' } } },
    headers: {},
    body: body === undefined || body === null ? null : JSON.stringify(body),
    httpMethod: httpMethod ?? (body === undefined ? 'GET' : 'POST'),
    isBase64Encoded: false,
    path: '/friends',
    pathParameters: null,
    queryStringParameters: queryStringParameters ?? null,
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('friends handlers', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockExtractAuth.mockReset();
    mockEnqueueFriendRealtimeEvent.mockReset();
    mockExtractAuth.mockResolvedValue({
      sub: 'user-1',
      username: 'user@example.com',
      phone: undefined,
      email: 'user@example.com',
      groups: ['Users'],
    });
  });

  it('searchUsersByUsername returns users with relation metadata and excludes self', async () => {
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [
        {
          id: 'user-2',
          name: 'Minh Tran',
          username: 'minh',
          avatarUrl: null,
          relationStatus: null,
          initiatedBy: null,
        },
      ],
    });

    const result = await searchUsersByUsername(
      mockEvent({ queryStringParameters: { username: ' Minh ' } }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('u.id <> $1'), [
      'user-1',
      'minh%',
      'minh',
    ]);
    expect(JSON.parse(result.body).users).toEqual([
      {
        id: 'user-2',
        name: 'Minh Tran',
        username: 'minh',
        avatarUrl: null,
        relationStatus: 'NONE',
        relationDirection: 'NONE',
        canRequest: true,
        canCancelRequest: false,
        canAcceptRequest: false,
      },
    ]);
  });

  it('searchUsersByUsername marks outgoing pending requests as cancelable', async () => {
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [
        {
          id: 'user-2',
          name: 'Minh Tran',
          username: 'minh',
          avatarUrl: null,
          relationStatus: 'PENDING',
          initiatedBy: 'user-1',
        },
      ],
    });

    const result = await searchUsersByUsername(
      mockEvent({ queryStringParameters: { username: 'minh' } }),
    );

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body).users).toEqual([
      {
        id: 'user-2',
        name: 'Minh Tran',
        username: 'minh',
        avatarUrl: null,
        relationStatus: 'PENDING',
        relationDirection: 'OUTGOING',
        canRequest: false,
        canCancelRequest: true,
        canAcceptRequest: false,
      },
    ]);
  });

  it('getSentFriendRequests returns pending requests initiated by the current user', async () => {
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [{ id: 'user-2', name: 'Minh Tran', username: 'minh', avatarUrl: null }],
    });

    const result = await getSentFriendRequests(mockEvent());

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('f.initiated_by = $1'), [
      'user-1',
    ]);
    expect(JSON.parse(result.body).requests).toEqual([
      { id: 'user-2', name: 'Minh Tran', username: 'minh', avatarUrl: null },
    ]);
  });

  it('hideFriend hides only the current users accepted friendship row and notifies the actor', async () => {
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'ACCEPTED' }] });
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [{ name: 'Minh Nguyen', username: 'minh', avatarUrl: null }],
    });

    const result = await hideFriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('SET is_hidden = TRUE'), [
      'user-1',
      'user-2',
    ]);
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledOnce();
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIENDSHIP_HIDDEN',
        targetUserId: 'user-1',
        actorUserId: 'user-1',
        relatedUserId: 'user-2',
      }),
    );
    expect(JSON.parse(result.body).success).toBe(true);
  });

  it('sendFriendRequest enqueues a realtime event after the friendship commit', async () => {
    mockQuery.mockResolvedValueOnce({ rowCount: 0, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [
        {
          name: 'Minh Nguyen',
          username: 'minh',
          avatarUrl: 'https://cdn.example/minh.png',
        },
      ],
    });

    const result = await sendFriendRequest(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(5, 'COMMIT');
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_REQUEST_RECEIVED',
        actorUserId: 'user-1',
        actorName: 'Minh Nguyen',
        actorUsername: 'minh',
        actorAvatarUrl: 'https://cdn.example/minh.png',
        relatedUserId: 'user-1',
        targetUserId: 'user-2',
      }),
    );
  });

  it('cancelFriendRequest deletes only outgoing pending rows and enqueues cancel realtime event', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'PENDING' }] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [{ name: 'Minh Nguyen', username: 'minh', avatarUrl: null }],
    });

    const result = await cancelFriendRequest(
      mockEvent({ body: { targetUserId: 'user-2' }, httpMethod: 'DELETE' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('initiated_by = $1'), [
      'user-1',
      'user-2',
    ]);
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_REQUEST_CANCELED',
        actorUserId: 'user-1',
        relatedUserId: 'user-1',
        targetUserId: 'user-2',
      }),
    );
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_REQUEST_CANCELED',
        actorUserId: 'user-1',
        relatedUserId: 'user-2',
        targetUserId: 'user-1',
      }),
    );
  });

  it('acceptFriend only accepts received pending requests', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 0, rows: [] });
    mockQuery.mockResolvedValueOnce({});

    const result = await acceptFriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error).toBe('No pending request found');
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('initiated_by != $1'), [
      'user-1',
      'user-2',
      expect.any(String),
    ]);
  });

  it('acceptFriend enqueues accepted realtime events for both users after commit', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'PENDING' }] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [{ name: 'Minh Nguyen', username: 'minh', avatarUrl: null }],
    });

    const result = await acceptFriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(6, 'COMMIT');
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_REQUEST_ACCEPTED',
        targetUserId: 'user-2',
        actorUserId: 'user-1',
        relatedUserId: 'user-1',
      }),
    );
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_REQUEST_ACCEPTED',
        targetUserId: 'user-1',
        actorUserId: 'user-1',
        relatedUserId: 'user-2',
      }),
    );
  });

  it('declineFriend only declines received pending requests', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 0, rows: [] });
    mockQuery.mockResolvedValueOnce({});

    const result = await declineFriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).error).toBe('No pending request found');
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('initiated_by != $1'), [
      'user-1',
      'user-2',
    ]);
  });

  it('declineFriend enqueues declined realtime events for both users after commit', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'PENDING' }] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [{ name: 'Minh Nguyen', username: 'minh', avatarUrl: null }],
    });

    const result = await declineFriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(4, 'COMMIT');
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_REQUEST_DECLINED',
        targetUserId: 'user-2',
        actorUserId: 'user-1',
        relatedUserId: 'user-1',
      }),
    );
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_REQUEST_DECLINED',
        targetUserId: 'user-1',
        actorUserId: 'user-1',
        relatedUserId: 'user-2',
      }),
    );
  });

  it('unfriend enqueues removed realtime events for both users after commit', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'ACCEPTED' }] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [{ name: 'Minh Nguyen', username: 'minh', avatarUrl: null }],
    });

    const result = await unfriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(6, 'COMMIT');
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIENDSHIP_REMOVED',
        targetUserId: 'user-2',
        actorUserId: 'user-1',
        relatedUserId: 'user-1',
      }),
    );
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIENDSHIP_REMOVED',
        targetUserId: 'user-1',
        actorUserId: 'user-1',
        relatedUserId: 'user-2',
      }),
    );
  });

  it('blockFriend marks caller row blocked, decrements accepted counters, and notifies both users', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'ACCEPTED' }] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [{ name: 'Minh Nguyen', username: 'minh', avatarUrl: null }],
    });

    const result = await blockFriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenNthCalledWith(1, 'BEGIN');
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining("status = 'BLOCKED'"), [
      'user-1',
      'user-2',
    ]);
    expect(mockQuery).toHaveBeenCalledWith(
      'UPDATE users SET friend_count = GREATEST(0, friend_count - 1) WHERE id = $1',
      ['user-1'],
    );
    expect(mockQuery).toHaveBeenCalledWith(
      'UPDATE users SET friend_count = GREATEST(0, friend_count - 1) WHERE id = $1',
      ['user-2'],
    );
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_BLOCKED',
        targetUserId: 'user-2',
        actorUserId: 'user-1',
        relatedUserId: 'user-1',
      }),
    );
    expect(mockEnqueueFriendRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'FRIEND_BLOCKED',
        targetUserId: 'user-1',
        actorUserId: 'user-1',
        relatedUserId: 'user-2',
      }),
    );
    expect(JSON.parse(result.body).success).toBe(true);
  });
});
