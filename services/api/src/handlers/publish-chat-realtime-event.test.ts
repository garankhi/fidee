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

import { handler } from './publish-chat-realtime-event';

const streamEvent = (eventName: 'INSERT' | 'MODIFY', type = 'MESSAGE_CREATED'): DynamoDBStreamEvent =>
  ({
    Records: [
      {
        eventName,
        dynamodb: {
          NewImage: {
            eventId: { S: 'message_created#user-2#conv-1#msg-1' },
            type: { S: type },
            targetUserId: { S: 'user-2' },
            conversationId: { S: 'conv-1' },
            message: {
              S: JSON.stringify({
                id: 'msg-1',
                conversationId: 'conv-1',
                senderId: 'user-1',
                clientMessageId: 'client-1',
                body: 'hello',
                status: 'SENT',
                createdAt: '2026-06-12T03:00:00.000Z',
              }),
            },
            receipt: { S: 'null' },
            typing: { S: 'null' },
            presence: { S: 'null' },
            createdAt: { S: '2026-06-12T03:00:00.000Z' },
          },
        },
      },
    ],
  }) as DynamoDBStreamEvent;

describe('publish chat realtime event handler', () => {
  beforeEach(() => {
    mockFetch.mockReset();
    mockFetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: { publishChatRealtimeEvent: {} } }),
    });
  });

  it('publishes chat INSERT records to AppSync with nested fields selected', async () => {
    await handler(streamEvent('INSERT'));

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [, init] = mockFetch.mock.calls[0];
    expect(init.body).toContain('publishChatRealtimeEvent');
    expect(init.body).toContain('message {');
    expect(JSON.parse(init.body).variables.input).toMatchObject({
      type: 'MESSAGE_CREATED',
      targetUserId: 'user-2',
      conversationId: 'conv-1',
      message: { id: 'msg-1', body: 'hello' },
    });
  });

  it('ignores non-insert and unknown event records', async () => {
    await handler(streamEvent('MODIFY'));
    await handler(streamEvent('INSERT', 'UNKNOWN_EVENT'));

    expect(mockFetch).not.toHaveBeenCalled();
  });
});
