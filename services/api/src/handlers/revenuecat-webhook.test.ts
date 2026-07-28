import type { APIGatewayProxyEvent } from 'aws-lambda';
import { describe, expect, it, vi } from 'vitest';
import { createRevenueCatWebhookHandler } from './revenuecat-webhook';

function mockEvent(
  event: Record<string, unknown>,
  authorization = 'Bearer test-secret',
): APIGatewayProxyEvent {
  return {
    body: JSON.stringify({ event }),
    headers: { Authorization: authorization },
  } as unknown as APIGatewayProxyEvent;
}

const lifecycleEvent = {
  id: 'evt-1',
  type: 'INITIAL_PURCHASE',
  app_user_id: '$RCAnonymousID:current',
  original_app_user_id: 'user-123',
  aliases: ['$RCAnonymousID:old', 'user-123'],
  product_id: 'fidee_pro_monthly',
  store: 'PLAY_STORE',
  expiration_at_ms: 1_800_000_000_000,
  event_timestamp_ms: 1_700_000_000_000,
  subscriber_attributes: {
    email: { value: 'private@example.com' },
  },
};

function setup(overrides: Record<string, unknown> = {}) {
  const deps = {
    loadAuthorization: vi.fn().mockResolvedValue('test-secret'),
    resolveUserIds: vi.fn().mockResolvedValue(['user-123']),
    recordEvent: vi.fn().mockResolvedValue({
      eventId: 'evt-1',
      state: 'pending',
      resolvedUserIds: ['user-123'],
    }),
    reconcile: vi.fn().mockResolvedValue({
      plan: 'PRO',
      entitlement: 'pro',
      reconciledAt: '2026-07-28T10:00:00.000Z',
    }),
    markProcessed: vi.fn().mockResolvedValue(undefined),
    deleteExpiredPendingIdentities: vi.fn().mockResolvedValue(0),
    ...overrides,
  };

  return {
    deps,
    handler: createRevenueCatWebhookHandler(deps),
  };
}

describe('RevenueCat webhook handler', () => {
  it('loads authorization from the server secret and compares it', async () => {
    const { handler, deps } = setup();

    const result = await handler(
      mockEvent(lifecycleEvent, 'Bearer wrong-secret'),
    );

    expect(result.statusCode).toBe(401);
    expect(deps.loadAuthorization).toHaveBeenCalledOnce();
    expect(deps.recordEvent).not.toHaveBeenCalled();
  });

  it('deduplicates app user, original user, and aliases', async () => {
    const { handler, deps } = setup();

    await handler(mockEvent(lifecycleEvent));

    expect(deps.resolveUserIds).toHaveBeenCalledWith([
      '$RCAnonymousID:current',
      'user-123',
      '$RCAnonymousID:old',
    ]);
    expect(deps.recordEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        candidateAppUserIds: [
          '$RCAnonymousID:current',
          'user-123',
          '$RCAnonymousID:old',
        ],
        payload: {
          eventId: 'evt-1',
          eventType: 'INITIAL_PURCHASE',
          productId: 'fidee_pro_monthly',
          store: 'PLAY_STORE',
          expiresAt: '2027-01-15T08:00:00.000Z',
          eventAt: '2023-11-14T22:13:20.000Z',
        },
      }),
    );
    expect(JSON.stringify(deps.recordEvent.mock.calls)).not.toContain(
      'private@example.com',
    );
  });

  it('records unresolved identity with retention and acknowledges it', async () => {
    const recordEvent = vi.fn().mockResolvedValue({
      eventId: 'evt-1',
      state: 'pending_identity',
      resolvedUserIds: [],
    });
    const { handler, deps } = setup({
      resolveUserIds: vi.fn().mockResolvedValue([]),
      recordEvent,
    });

    const result = await handler(mockEvent(lifecycleEvent));

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body).status).toBe('pending_identity');
    expect(recordEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        state: 'pending_identity',
        resolvedUserIds: [],
      }),
    );
    expect(deps.reconcile).not.toHaveBeenCalled();
  });

  it('returns duplicate processed events without reconciliation', async () => {
    const { handler, deps } = setup({
      recordEvent: vi.fn().mockResolvedValue({
        eventId: 'evt-1',
        state: 'processed',
        resolvedUserIds: ['user-123'],
      }),
    });

    const result = await handler(mockEvent(lifecycleEvent));

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body).status).toBe('duplicate');
    expect(deps.reconcile).not.toHaveBeenCalled();
  });

  it('retries duplicate pending events using current RevenueCat state', async () => {
    const { handler, deps } = setup();

    const result = await handler(
      mockEvent({ ...lifecycleEvent, type: 'CANCELLATION' }),
    );

    expect(result.statusCode).toBe(200);
    expect(deps.reconcile).toHaveBeenCalledWith({
      userId: 'user-123',
      revenueCatCustomerId: 'user-123',
    });
    expect(deps.markProcessed).toHaveBeenCalledWith('evt-1', ['user-123']);
  });

  it.each(['BILLING_ISSUE', 'REFUND', 'EXPIRATION'])(
    'uses verifier reconciliation rather than event mapping for %s',
    async (type) => {
      const { handler, deps } = setup();

      await handler(mockEvent({ ...lifecycleEvent, type }));

      expect(deps.reconcile).toHaveBeenCalledOnce();
      expect(deps.reconcile).not.toHaveBeenCalledWith(
        expect.objectContaining({ plan: 'FREE' }),
      );
    },
  );

  it('keeps failed known reconciliation pending and returns non-2xx', async () => {
    const { handler, deps } = setup({
      reconcile: vi.fn().mockRejectedValue(new Error('temporary failure')),
    });

    const result = await handler(mockEvent(lifecycleEvent));

    expect(result.statusCode).toBe(503);
    expect(deps.markProcessed).not.toHaveBeenCalled();
  });

  it('marks unknown event types processed without plan mutation', async () => {
    const { handler, deps } = setup();

    const result = await handler(
      mockEvent({ ...lifecycleEvent, type: 'TEST' }),
    );

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body).status).toBe('ignored');
    expect(deps.reconcile).not.toHaveBeenCalled();
    expect(deps.markProcessed).toHaveBeenCalledWith('evt-1', ['user-123']);
  });

  it('reconciles every known user on both sides of a transfer', async () => {
    const resolveUserIds = vi
      .fn()
      .mockResolvedValue(['user-from', 'user-to']);
    const reconcile = vi.fn().mockResolvedValue({
      plan: 'PRO',
      entitlement: 'pro',
      reconciledAt: '2026-07-28T10:00:00.000Z',
    });
    const recordEvent = vi.fn().mockResolvedValue({
      eventId: 'evt-transfer',
      state: 'pending',
      resolvedUserIds: ['user-from', 'user-to'],
    });
    const { handler } = setup({
      resolveUserIds,
      recordEvent,
      reconcile,
    });

    const result = await handler(
      mockEvent({
        id: 'evt-transfer',
        type: 'TRANSFER',
        transferred_from: ['user-from', '$RCAnonymousID:from'],
        transferred_to: ['user-to', '$RCAnonymousID:to'],
        event_timestamp_ms: 1_700_000_000_000,
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(resolveUserIds).toHaveBeenCalledWith([
      'user-from',
      '$RCAnonymousID:from',
      'user-to',
      '$RCAnonymousID:to',
    ]);
    expect(reconcile).toHaveBeenCalledTimes(2);
    expect(reconcile).toHaveBeenCalledWith({
      userId: 'user-from',
      revenueCatCustomerId: 'user-from',
    });
    expect(reconcile).toHaveBeenCalledWith({
      userId: 'user-to',
      revenueCatCustomerId: 'user-to',
    });
  });

  it('opportunistically deletes expired pending identities', async () => {
    const { handler, deps } = setup();

    await handler(mockEvent(lifecycleEvent));

    expect(deps.deleteExpiredPendingIdentities).toHaveBeenCalledOnce();
  });
});
