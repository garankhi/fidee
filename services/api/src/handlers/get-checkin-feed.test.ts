import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery, mockExtractAuth } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockExtractAuth: vi.fn(),
}));

vi.mock('../db/client', () => ({ query: mockQuery }));
vi.mock('../middleware/auth', () => ({ extractAuth: mockExtractAuth }));

import { handler } from './get-checkin-feed';

const event = (queryStringParameters?: Record<string, string>): APIGatewayProxyEvent =>
  ({
    headers: {},
    body: null,
    httpMethod: 'GET',
    isBase64Encoded: false,
    path: '/feed/checkins',
    pathParameters: null,
    queryStringParameters: queryStringParameters ?? null,
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    requestContext: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('get-checkin-feed handler', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockExtractAuth.mockReset();
    mockExtractAuth.mockResolvedValue({ sub: 'user-1' });
  });

  it('defaults to everyone sorted newest first', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [] });

    const result = await handler(event());

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('ORDER BY ci.created_at DESC'), [
      'user-1',
      21,
    ]);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('ci.user_id = $1'), [
      'user-1',
      21,
    ]);
  });

  it('filters to current user for filter=me', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [] });

    const result = await handler(event({ filter: 'me', limit: '12' }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('ci.user_id = $1'), [
      'user-1',
      13,
    ]);
  });

  it('includes direct shares targeted to the viewer in everyone feed', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [] });

    const result = await handler(event({ filter: 'everyone', limit: '12' }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('check_in_recipients'), [
      'user-1',
      13,
    ]);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining("ci.audience_type = 'ALL_FRIENDS'"), [
      'user-1',
      13,
    ]);
  });

  it('filters to selected friend posts without leaking untargeted direct shares', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [] });

    const result = await handler(event({ filter: 'everyone', friendId: 'friend-1' }));

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('ci.user_id = $3'), [
      'user-1',
      21,
      'friend-1',
    ]);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining("status = 'ACCEPTED'"), [
      'user-1',
      21,
      'friend-1',
    ]);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('check_in_recipients'), [
      'user-1',
      21,
      'friend-1',
    ]);
  });

  it('returns 401 when auth extraction fails', async () => {
    mockExtractAuth.mockRejectedValueOnce(new Error('no auth'));

    const result = await handler(event({ filter: 'everyone' }));

    expect(result.statusCode).toBe(401);
  });
});
