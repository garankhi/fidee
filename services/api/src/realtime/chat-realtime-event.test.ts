import { beforeEach, describe, expect, it, vi } from 'vitest';

const { mockSend } = vi.hoisted(() => ({
  mockSend: vi.fn(),
}));

vi.mock('@aws-sdk/client-dynamodb', () => {
  class PutItemCommand {
    input: unknown;

    constructor(input: unknown) {
      this.input = input;
    }
  }

  return {
    DynamoDBClient: vi.fn(() => ({ send: mockSend })),
    PutItemCommand,
  };
});

import { enqueueChatRealtimeEvent } from './chat-realtime-event';

describe('enqueueChatRealtimeEvent', () => {
  beforeEach(() => {
    vi.stubEnv('CHAT_REALTIME_EVENTS_TABLE', 'chat-events');
    mockSend.mockReset();
    mockSend.mockResolvedValue({});
  });

  it('stores message events with nested payload JSON and ttl', async () => {
    await enqueueChatRealtimeEvent({
      type: 'MESSAGE_CREATED',
      targetUserId: 'user-2',
      conversationId: 'conv-1',
      message: {
        id: 'msg-1',
        conversationId: 'conv-1',
        senderId: 'user-1',
        clientMessageId: 'client-1',
        body: 'hello',
        status: 'SENT',
        createdAt: '2026-06-12T03:00:00.000Z',
      },
      createdAt: '2026-06-12T03:00:00.000Z',
    });

    const command = mockSend.mock.calls[0][0] as { input: any };

    expect(command.input.TableName).toBe('chat-events');
    expect(command.input.Item.eventId.S).toContain('message_created#user-2#conv-1#msg-1');
    expect(command.input.Item.type.S).toBe('MESSAGE_CREATED');
    expect(JSON.parse(command.input.Item.message.S)).toMatchObject({
      id: 'msg-1',
      body: 'hello',
    });
    expect(Number(command.input.Item.expiresAt.N)).toBeGreaterThan(Math.floor(Date.now() / 1000));
  });
});
