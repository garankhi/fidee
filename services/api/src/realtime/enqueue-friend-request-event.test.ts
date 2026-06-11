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

import { enqueueFriendRequestRealtimeEvent } from './enqueue-friend-request-event';

describe('enqueueFriendRequestRealtimeEvent', () => {
  beforeEach(() => {
    vi.stubEnv('FRIEND_REQUEST_REALTIME_EVENTS_TABLE', 'friend-events');
    mockSend.mockReset();
    mockSend.mockResolvedValue({});
  });

  it('uses a unique event id for each friend request attempt', async () => {
    await enqueueFriendRequestRealtimeEvent({
      requesterId: 'user-1',
      requesterName: 'Minh Nguyen',
      requesterUsername: 'minh',
      requesterAvatarUrl: null,
      targetUserId: 'user-2',
      createdAt: '2026-06-11T03:00:00.000Z',
    });
    await enqueueFriendRequestRealtimeEvent({
      requesterId: 'user-1',
      requesterName: 'Minh Nguyen',
      requesterUsername: 'minh',
      requesterAvatarUrl: null,
      targetUserId: 'user-2',
      createdAt: '2026-06-11T03:01:00.000Z',
    });

    const firstCommand = mockSend.mock.calls[0][0] as { input: any };
    const secondCommand = mockSend.mock.calls[1][0] as { input: any };
    const firstEventId = firstCommand.input.Item.eventId.S;
    const secondEventId = secondCommand.input.Item.eventId.S;

    expect(firstEventId).toContain('friend_request#user-1#user-2#');
    expect(secondEventId).toContain('friend_request#user-1#user-2#');
    expect(firstEventId).not.toBe(secondEventId);
  });
});
