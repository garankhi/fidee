import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery, mockExtractAuth } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockExtractAuth: vi.fn(),
}));

vi.mock('../db/client', () => ({
  query: mockQuery,
}));

vi.mock('../middleware/auth', () => ({
  extractAuth: mockExtractAuth,
}));

import { blockFriend, hideFriend, searchUsersByUsername } from './friends-handlers';

const mockEvent = ({
  body,
  queryStringParameters,
}: {
  body?: Record<string, unknown> | null;
  queryStringParameters?: Record<string, string> | null;
} = {}): APIGatewayProxyEvent =>
  ({
    requestContext: { authorizer: { claims: { sub: 'user-1' } } },
    headers: {},
    body: body === undefined || body === null ? null : JSON.stringify(body),
    httpMethod: body === undefined ? 'GET' : 'POST',
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
        canRequest: true,
      },
    ]);
  });

  it('hideFriend hides only the current users accepted friendship row', async () => {
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'ACCEPTED' }] });

    const result = await hideFriend(mockEvent({ body: { targetUserId: 'user-2' } }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('SET is_hidden = TRUE'), [
      'user-1',
      'user-2',
    ]);
    expect(JSON.parse(result.body).success).toBe(true);
  });

  it('blockFriend marks caller row blocked and decrements accepted counters', async () => {
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ status: 'ACCEPTED' }] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    mockQuery.mockResolvedValueOnce({});
    mockQuery.mockResolvedValueOnce({});

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
    expect(JSON.parse(result.body).success).toBe(true);
  });
});
