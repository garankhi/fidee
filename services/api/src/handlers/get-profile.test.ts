import { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockExtractAuth, mockQuery } = vi.hoisted(() => ({
  mockExtractAuth: vi.fn(),
  mockQuery: vi.fn(),
}));

vi.mock('../middleware/auth', () => ({
  extractAuth: mockExtractAuth,
  maskPhone: (phone: string): string => phone,
  maskEmail: (email: string): string => email,
}));

vi.mock('../db/client', () => ({
  query: mockQuery,
}));

import { handler } from './get-profile';

const event = {} as APIGatewayProxyEvent;

describe('get-profile handler', () => {
  beforeEach(() => {
    mockExtractAuth.mockReset();
    mockQuery.mockReset();
    mockExtractAuth.mockResolvedValue({
      sub: 'user-1',
      phone: undefined,
      email: 'user@example.com',
      groups: ['Users'],
    });
  });

  it('returns exact separate profile names', async () => {
    mockQuery
      .mockResolvedValueOnce({
        rowCount: 1,
        rows: [
          {
            id: 'user-1',
            display_name: 'Minh 2 Nguyen',
            family_name: 'Minh 2',
            given_name: 'Nguyen',
            username: 'minh',
            avatar_url: null,
            bio: null,
            plan: 'FREE',
            created_at: '2026-01-02T00:00:00.000Z',
            friend_count: 0,
            place_count: 0,
            checkin_count: 0,
          },
        ],
      })
      .mockResolvedValueOnce({ rowCount: 0, rows: [] });

    const result = await handler(event);
    const body = JSON.parse(result.body);

    expect(result.statusCode).toBe(200);
    expect(mockQuery.mock.calls[0][0]).toContain('family_name');
    expect(body.firstName).toBe('Minh 2');
    expect(body.lastName).toBe('Nguyen');
    expect(body.displayName).toBe('Minh 2 Nguyen');
  });

  it('returns 401 when authentication fails', async () => {
    mockExtractAuth.mockRejectedValueOnce(new Error('Missing auth context: no sub claim found'));

    const result = await handler(event);

    expect(result.statusCode).toBe(401);
  });
});
