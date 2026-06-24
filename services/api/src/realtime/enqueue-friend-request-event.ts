import { enqueueFriendRealtimeEvent } from './friend-realtime-event';

export interface FriendRequestRealtimeEventInput {
  type?: 'FRIEND_REQUEST_RECEIVED' | 'FRIEND_REQUEST_CANCELED';
  requesterId: string;
  requesterName: string;
  requesterUsername?: string | null;
  requesterAvatarUrl?: string | null;
  targetUserId: string;
  createdAt: string;
}

export async function enqueueFriendRequestRealtimeEvent(
  input: FriendRequestRealtimeEventInput,
): Promise<void> {
  await enqueueFriendRealtimeEvent({
    type: input.type ?? 'FRIEND_REQUEST_RECEIVED',
    targetUserId: input.targetUserId,
    actorUserId: input.requesterId,
    relatedUserId: input.requesterId,
    actorName: input.requesterName,
    actorUsername: input.requesterUsername,
    actorAvatarUrl: input.requesterAvatarUrl,
    createdAt: input.createdAt,
  });
}
