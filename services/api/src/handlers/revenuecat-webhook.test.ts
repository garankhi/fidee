import { APIGatewayProxyEvent } from 'aws-lambda';
import { describe, expect, it, vi } from 'vitest';
import { createRevenueCatWebhookHandler } from './revenuecat-webhook';

function mockEvent(
  body: Record<string, unknown>,
  authorization = 'Bearer test-secret',
): APIGatewayProxyEvent {
  return {
    body: JSON.stringify(body),
    headers: { Authorization: authorization },
  } as unknown as APIGatewayProxyEvent;
}

const activePayload = {
  event: {
    id: 'evt-1',
    type: 'INITIAL_PURCHASE',
    app_user_id: 'user-123',
    product_id: 'fidee_pro_monthly',
    store: 'TEST_STORE',
    expiration_at_ms: 1799999999000,
    event_timestamp_ms: 1760000000000,
  },
};

function setup(overrides = {}) {
  return createRevenueCatWebhookHandler({
    env: { webhookSecret: 'test-secret' },
    recordEvent: vi.fn().mockResolvedValue('created'),
    syncSubscription: vi.fn().mockResolvedValue(undefined),
    markProcessed: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  });
}

describe('RevenueCat webhook handler', () => {
  it('returns 401 when secret is missing', async () => {
    const handler = setup();

    const result = await handler(mockEvent(activePayload, 'Bearer wrong-secret'));

    expect(result.statusCode).toBe(401);
  });

  it('treats duplicate event ids as idempotent', async () => {
    const syncSubscription = vi.fn();
    const handler = setup({
      recordEvent: vi.fn().mockResolvedValue('duplicate'),
      syncSubscription,
    });

    const result = await handler(mockEvent(activePayload));

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body).status).toBe('duplicate');
    expect(syncSubscription).not.toHaveBeenCalled();
  });

  it('maps active event to PRO', async () => {
    const syncSubscription = vi.fn().mockResolvedValue(undefined);
    const handler = setup({ syncSubscription });

    const result = await handler(mockEvent(activePayload));

    expect(result.statusCode).toBe(200);
    expect(syncSubscription).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-123',
        revenueCatAppUserId: 'user-123',
        plan: 'PRO',
        productId: 'fidee_pro_monthly',
        store: 'TEST_STORE',
      }),
    );
  });

  it('maps expiration event to FREE', async () => {
    const syncSubscription = vi.fn().mockResolvedValue(undefined);
    const handler = setup({ syncSubscription });

    const result = await handler(
      mockEvent({
        event: {
          ...activePayload.event,
          id: 'evt-2',
          type: 'EXPIRATION',
        },
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(syncSubscription).toHaveBeenCalledWith(expect.objectContaining({ plan: 'FREE' }));
  });
});
