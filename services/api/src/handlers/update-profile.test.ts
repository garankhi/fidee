import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery, mockExtractAuth, mockCognitoSend } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockExtractAuth: vi.fn(),
  mockCognitoSend: vi.fn(),
}));

vi.mock('../db/client', () => ({
  query: mockQuery,
}));

vi.mock('../middleware/auth', () => ({
  extractAuth: mockExtractAuth,
}));

vi.mock('@aws-sdk/client-cognito-identity-provider', () => ({
  CognitoIdentityProviderClient: vi.fn().mockImplementation(() => ({
    send: mockCognitoSend,
  })),
  AdminUpdateUserAttributesCommand: vi.fn().mockImplementation((input) => ({ input })),
}));

import { handler } from './update-profile';

const mockEvent = (body: Record<string, unknown> | null): APIGatewayProxyEvent =>
  ({
    requestContext: { authorizer: { claims: { sub: 'user-1' } } },
    headers: {},
    body: body === null ? null : JSON.stringify(body),
    httpMethod: 'PATCH',
    isBase64Encoded: false,
    path: '/profile',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    multiValueHeaders: {},
    stageVariables: null,
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('update-profile handler', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockExtractAuth.mockReset();
    mockCognitoSend.mockReset();
    delete process.env.COGNITO_PROFILE_MIRROR_TIMEOUT_MS;
    process.env.COGNITO_USER_POOL_ID = 'pool-1';
    mockExtractAuth.mockResolvedValue({
      sub: 'user-1',
      username: 'user@example.com',
      phone: undefined,
      email: 'user@example.com',
      groups: ['Users'],
    });
  });

  it('updates profile and mirrors Cognito attributes when username is available', async () => {
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [
        {
          id: 'user-1',
          display_name: 'Nguyen Minh',
          username: 'minh',
          avatar_url: null,
          bio: 'Coffee hunter',
          plan: 'FREE',
          created_at: '2026-01-02T00:00:00.000Z',
        },
      ],
    });
    mockCognitoSend.mockResolvedValueOnce({});

    const result = await handler(
      mockEvent({
        firstName: ' Nguyen ',
        lastName: 'Minh',
        username: 'Minh',
        bio: 'Coffee hunter',
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('INSERT INTO users'), [
      'user-1',
      'Nguyen Minh',
      'minh',
      'user@example.com',
      null,
      'Coffee hunter',
    ]);
    expect(mockCognitoSend).toHaveBeenCalledWith(
      expect.objectContaining({
        input: expect.objectContaining({
          UserPoolId: 'pool-1',
          Username: 'user@example.com',
        }),
      }),
      expect.objectContaining({ abortSignal: expect.any(Object) }),
    );
    expect(JSON.parse(result.body).profile.username).toBe('minh');
    expect(JSON.parse(result.body).profile.bio).toBe('Coffee hunter');
  });

  it('does not block the profile response when Cognito mirror hangs', async () => {
    process.env.COGNITO_PROFILE_MIRROR_TIMEOUT_MS = '1';
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [
        {
          id: 'user-1',
          display_name: 'Nguyen Minh',
          username: 'minh',
          avatar_url: null,
          bio: null,
          plan: 'FREE',
          created_at: '2026-01-02T00:00:00.000Z',
        },
      ],
    });
    mockCognitoSend.mockImplementationOnce((_command, options) => {
      if (!options?.abortSignal) {
        return new Promise(() => undefined);
      }

      return new Promise((_, reject) => {
        options.abortSignal.addEventListener('abort', () => reject(new Error('aborted')));
      });
    });

    const result = await Promise.race([
      handler(mockEvent({ firstName: 'Nguyen', lastName: 'Minh', username: 'minh' })),
      new Promise<'timed-out'>((resolve) => setTimeout(() => resolve('timed-out'), 100)),
    ]);

    expect(result).not.toBe('timed-out');
    expect(result).toEqual(expect.objectContaining({ statusCode: 200 }));
  });

  it('returns 409 when username is already used by another user', async () => {
    mockQuery.mockResolvedValueOnce({ rowCount: 0, rows: [] });

    const result = await handler(
      mockEvent({ firstName: 'Nguyen', lastName: 'Minh', username: 'taken' }),
    );

    expect(result.statusCode).toBe(409);
    expect(JSON.parse(result.body).code).toBe('USERNAME_TAKEN');
    expect(mockCognitoSend).not.toHaveBeenCalled();
  });

  it('allows saving the current username for the same user', async () => {
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [
        {
          id: 'user-1',
          display_name: 'Nguyen Minh',
          username: 'current',
          avatar_url: null,
          bio: null,
          plan: 'FREE',
          created_at: '2026-01-02T00:00:00.000Z',
        },
      ],
    });

    const result = await handler(
      mockEvent({ firstName: 'Nguyen', lastName: 'Minh', username: 'current' }),
    );

    expect(result.statusCode).toBe(200);
  });

  it('creates the profile row when the authenticated user has not been synced yet', async () => {
    mockQuery.mockResolvedValueOnce({
      rowCount: 1,
      rows: [
        {
          id: 'user-1',
          display_name: 'Nguyen Minh',
          username: 'newuser',
          avatar_url: null,
          bio: null,
          plan: 'FREE',
          created_at: '2026-01-02T00:00:00.000Z',
        },
      ],
    });

    const result = await handler(
      mockEvent({ firstName: 'Nguyen', lastName: 'Minh', username: 'newuser' }),
    );

    expect(result.statusCode).toBe(200);
    expect(mockQuery).toHaveBeenCalledTimes(1);
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining('INSERT INTO users'), [
      'user-1',
      'Nguyen Minh',
      'newuser',
      'user@example.com',
      null,
      null,
    ]);
    expect(JSON.parse(result.body).profile.username).toBe('newuser');
  });

  it('returns 400 for invalid usernames', async () => {
    const result = await handler(
      mockEvent({ firstName: 'Nguyen', lastName: 'Minh', username: 'bad name' }),
    );

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).code).toBe('VALIDATION_ERROR');
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('returns 401 when auth context is missing', async () => {
    mockExtractAuth.mockRejectedValueOnce(new Error('Missing auth context: no sub claim found'));

    const result = await handler(
      mockEvent({ firstName: 'Nguyen', lastName: 'Minh', username: 'minh' }),
    );

    expect(result.statusCode).toBe(401);
  });
});
