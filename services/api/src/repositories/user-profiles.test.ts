import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { describe, expect, it, vi } from 'vitest';
import { setUserPlan } from './user-profiles';

describe('user profile plan repository', () => {
  it('fails when USER_PROFILES_TABLE is not configured', async () => {
    const client = {
      send: vi.fn(),
    } as unknown as DynamoDBDocumentClient;

    await expect(setUserPlan('user-1', 'PRO', '', client)).rejects.toThrow(
      'USER_PROFILES_TABLE is required',
    );
    expect(client.send).not.toHaveBeenCalled();
  });
});
