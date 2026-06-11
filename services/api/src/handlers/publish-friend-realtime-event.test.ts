import { DynamoDBStreamEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockFetch } = vi.hoisted(() => ({
  mockFetch: vi.fn(),
}));

vi.stubEnv(
  'FRIEND_REALTIME_GRAPHQL_URL',
  'https://abc123.appsync-api.ap-southeast-1.amazonaws.com/graphql',
);
vi.stubEnv('AWS_REGION', 'ap-southeast-1');

vi.stubGlobal('fetch', mockFetch);

vi.mock('@aws-sdk/credential-provider-node', () => ({
  defaultProvider: () => async () => ({
    accessKeyId: 'AKIATEST',
    secretAccessKey: 'secret',
  }),
}));

import { handler } from './publish-friend-realtime-event';

const streamEvent = (
  eventName: 'INSERT' | 'MODIFY',
  type = 'FRIEND_REQUEST_RECEIVED',
): DynamoDBStreamEvent =>
  ({
    Records: [
      {
        eventName,
        dynamodb: {
          NewImage: {
            eventId: { S: 'friend_request#user-1#user-2' },
            type: { S: type },
            targetUserId: { S: 'user-2' },
            requesterId: { S: 'user-1' },
            requesterName: { S: 'Minh Nguyen' },
            requesterUsername: { S: 'minh' },
            requesterAvatarUrl: { S: 'https://cdn.example/minh.png' },
            createdAt: { S: '2026-06-11T03:00:00.000Z' },
          },
        },
      },
    ],
  }) as DynamoDBStreamEvent;

describe('publish friend realtime event handler', () => {
  beforeEach(() => {
    mockFetch.mockReset();
    mockFetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: { publishFriendRequestReceived: {} } }),
    });
  });

  it('publishes friend request INSERT records to AppSync', async () => {
    await handler(streamEvent('INSERT'));

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [, init] = mockFetch.mock.calls[0];
    expect(init.method).toBe('POST');
    expect(init.body).toContain('publishFriendRequestReceived');
    expect(JSON.parse(init.body).variables.input).toMatchObject({
      targetUserId: 'user-2',
      requesterId: 'user-1',
      requesterName: 'Minh Nguyen',
    });
  });

  it('publishes friend request canceled INSERT records to AppSync', async () => {
    await handler(streamEvent('INSERT', 'FRIEND_REQUEST_CANCELED'));

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [, init] = mockFetch.mock.calls[0];
    expect(init.body).toContain('publishFriendRequestCanceled');
    expect(JSON.parse(init.body).variables.input.type).toBe('FRIEND_REQUEST_CANCELED');
  });

  it('throws when AppSync returns GraphQL errors with a 200 response', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ errors: [{ message: 'Unauthorized' }] }),
    });

    await expect(handler(streamEvent('INSERT'))).rejects.toThrow('AppSync publish failed');
  });

  it('ignores non-insert stream records', async () => {
    await handler(streamEvent('MODIFY'));

    expect(mockFetch).not.toHaveBeenCalled();
  });
});
