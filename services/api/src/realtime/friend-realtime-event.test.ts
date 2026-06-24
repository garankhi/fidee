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

import { enqueueFriendRealtimeEvent } from './friend-realtime-event';

describe('enqueueFriendRealtimeEvent', () => {
  beforeEach(() => {
    vi.stubEnv('FRIEND_REQUEST_REALTIME_EVENTS_TABLE', 'friend-events');
    mockSend.mockReset();
    mockSend.mockResolvedValue({});
  });

  it('stores a generic friendship event with subscriber and actor context', async () => {
    await enqueueFriendRealtimeEvent({
      type: 'FRIENDSHIP_REMOVED',
      targetUserId: 'user-2',
      actorUserId: 'user-1',
      relatedUserId: 'user-1',
      actorName: 'Minh Nguyen',
      actorUsername: 'minh',
      actorAvatarUrl: null,
      createdAt: '2026-06-12T03:00:00.000Z',
    });

    const command = mockSend.mock.calls[0][0] as { input: any };

    expect(command.input.TableName).toBe('friend-events');
    expect(command.input.Item.eventId.S).toContain('friendship_removed#user-2#user-1#');
    expect(command.input.Item.type.S).toBe('FRIENDSHIP_REMOVED');
    expect(command.input.Item.targetUserId.S).toBe('user-2');
    expect(command.input.Item.actorUserId.S).toBe('user-1');
    expect(command.input.Item.relatedUserId.S).toBe('user-1');
    expect(command.input.Item.actorName.S).toBe('Minh Nguyen');
    expect(command.input.Item.actorUsername.S).toBe('minh');
    expect(command.input.Item.actorAvatarUrl.S).toBe('');
    expect(Number(command.input.Item.expiresAt.N)).toBeGreaterThan(Math.floor(Date.now() / 1000));
  });

  it('uses unique ids for repeated events between the same users', async () => {
    await enqueueFriendRealtimeEvent({
      type: 'FRIEND_REQUEST_ACCEPTED',
      targetUserId: 'user-1',
      actorUserId: 'user-2',
      relatedUserId: 'user-2',
      actorName: 'Tran An',
      actorUsername: null,
      actorAvatarUrl: null,
      createdAt: '2026-06-12T03:00:00.000Z',
    });
    await enqueueFriendRealtimeEvent({
      type: 'FRIEND_REQUEST_ACCEPTED',
      targetUserId: 'user-1',
      actorUserId: 'user-2',
      relatedUserId: 'user-2',
      actorName: 'Tran An',
      actorUsername: null,
      actorAvatarUrl: null,
      createdAt: '2026-06-12T03:01:00.000Z',
    });

    const firstCommand = mockSend.mock.calls[0][0] as { input: any };
    const secondCommand = mockSend.mock.calls[1][0] as { input: any };

    expect(firstCommand.input.Item.eventId.S).not.toBe(secondCommand.input.Item.eventId.S);
  });
});
