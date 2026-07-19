import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockQuery, mockDynamoSend } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockDynamoSend: vi.fn(),
}));

vi.mock('../db/client', () => ({ query: mockQuery }));
vi.mock('@aws-sdk/client-dynamodb', () => ({ DynamoDBClient: vi.fn() }));
vi.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: {
    from: vi.fn(() => ({ send: mockDynamoSend })),
  },
  UpdateCommand: vi.fn((input) => ({ input })),
}));

import { syncUserToDatabases } from './sync-user';

describe('syncUserToDatabases profile names', () => {
  beforeEach(() => {
    mockQuery.mockReset();
    mockDynamoSend.mockReset();
    delete process.env.USER_PROFILES_TABLE;
  });

  it('inserts family before given name and only fills missing stored names', async () => {
    const oldNodeEnv = process.env.NODE_ENV;
    const oldVitest = process.env.VITEST;
    process.env.NODE_ENV = 'development';
    delete process.env.VITEST;
    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });

    try {
      await syncUserToDatabases({
        sub: 'user-1',
        email: 'user@example.com',
        familyName: 'Minh 2',
        givenName: 'Nguyen',
      });
    } finally {
      if (oldNodeEnv == null) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = oldNodeEnv;
      if (oldVitest == null) delete process.env.VITEST;
      else process.env.VITEST = oldVitest;
    }

    const [sql, params] = mockQuery.mock.calls[0];
    expect(sql).toContain('family_name = COALESCE(users.family_name');
    expect(sql).toContain('given_name = COALESCE(users.given_name');
    expect(sql).not.toContain('display_name = COALESCE($7::text, users.display_name)');
    expect(params).toEqual([
      'user-1',
      'Minh 2 Nguyen',
      'Minh 2',
      'Nguyen',
      null,
      'user@example.com',
      null,
      null,
    ]);
  });
});
