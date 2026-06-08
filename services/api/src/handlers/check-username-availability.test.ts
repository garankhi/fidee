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

import { handler } from './check-username-availability';

const mockEvent = (username?: string): APIGatewayProxyEvent =>
  ({
    requestContext: { authorizer: { claims: { sub: 'user-1' } } },
    headers: {},
    body: null,
    httpMethod: 'GET',
    isBase64Encoded: false,
    path: '/profile/username-availability',
    pathParameters: null,
    queryStringParameters: username === undefined ? null : { username },
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('check-username-availability handler', () => {
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

  it('returns available when no other user has the normalized username', async () => {
    mockQuery.mockResolvedValueOnce({ rowCount: 0, rows: [] });

    const result = await handler(mockEvent(' Minh.Handle '));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('username = $1'), [
      'minh.handle',
      'user-1',
    ]);
    expect(JSON.parse(result.body)).toEqual({
      username: 'minh.handle',
      available: true,
      reason: null,
    });
  });

  it('returns unavailable when another user already has the username', async () => {
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [{ id: 'user-2' }] });

    const result = await handler(mockEvent('taken'));

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body)).toEqual({
      username: 'taken',
      available: false,
      reason: 'USERNAME_TAKEN',
    });
  });

  it('returns 400 for invalid usernames without querying', async () => {
    const result = await handler(mockEvent('bad name'));

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).code).toBe('VALIDATION_ERROR');
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('returns 401 when auth context is missing', async () => {
    mockExtractAuth.mockRejectedValueOnce(new Error('Missing auth context: no sub claim found'));

    const result = await handler(mockEvent('minh'));

    expect(result.statusCode).toBe(401);
  });
});
