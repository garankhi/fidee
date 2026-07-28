import type { APIGatewayProxyEvent } from 'aws-lambda';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RevenueCatVerificationError } from '../services/revenuecat-client';

const { mockExtractAuth } = vi.hoisted(() => ({
  mockExtractAuth: vi.fn(),
}));

vi.mock('../middleware/auth', () => ({
  extractAuth: mockExtractAuth,
}));

import { createSyncRevenueCatCustomerHandler } from './sync-revenuecat-customer';

function event(body: unknown): APIGatewayProxyEvent {
  return {
    body: typeof body === 'string' ? body : JSON.stringify(body),
  } as APIGatewayProxyEvent;
}

describe('sync RevenueCat customer handler', () => {
  beforeEach(() => {
    mockExtractAuth.mockReset();
    mockExtractAuth.mockResolvedValue({
      sub: 'trusted-user',
      email: 'user@example.com',
      groups: ['Users'],
    });
  });

  it('uses auth.sub as the only user and customer authority', async () => {
    const reconcile = vi.fn().mockResolvedValue({
      plan: 'PRO',
      entitlement: 'pro',
      reconciledAt: '2026-07-28T10:00:00.000Z',
    });
    const handler = createSyncRevenueCatCustomerHandler({ reconcile });

    const result = await handler(
      event({
        appUserId: 'forged-user',
        activeEntitlementIds: ['pro'],
      }),
    );

    expect(result.statusCode).toBe(200);
    expect(reconcile).toHaveBeenCalledWith({
      userId: 'trusted-user',
      revenueCatCustomerId: 'trusted-user',
    });
    expect(JSON.parse(result.body)).toEqual({
      plan: 'PRO',
      entitlement: 'pro',
      reconciledAt: '2026-07-28T10:00:00.000Z',
    });
  });

  it('accepts an empty JSON object for the authoritative client', async () => {
    const reconcile = vi.fn().mockResolvedValue({
      plan: 'FREE',
      entitlement: 'free',
      reconciledAt: '2026-07-28T10:00:00.000Z',
    });
    const handler = createSyncRevenueCatCustomerHandler({ reconcile });

    const result = await handler(event({}));

    expect(result.statusCode).toBe(200);
    expect(reconcile).toHaveBeenCalledOnce();
  });

  it('maps retryable verification failures to 503', async () => {
    const handler = createSyncRevenueCatCustomerHandler({
      reconcile: vi.fn().mockRejectedValue(
        new RevenueCatVerificationError(
          'retryable',
          503,
          'safe retryable failure',
        ),
      ),
    });

    const result = await handler(event({}));

    expect(result.statusCode).toBe(503);
    expect(JSON.parse(result.body)).toEqual({
      code: 'REVENUECAT_SYNC_RETRYABLE',
      error: 'RevenueCat synchronization is temporarily unavailable',
    });
  });

  it('maps configuration failures to 500 without exposing credentials', async () => {
    const handler = createSyncRevenueCatCustomerHandler({
      reconcile: vi.fn().mockRejectedValue(
        new RevenueCatVerificationError(
          'configuration',
          401,
          'secret-value Authorization Bearer',
        ),
      ),
    });

    const result = await handler(event({}));

    expect(result.statusCode).toBe(500);
    expect(JSON.parse(result.body)).toEqual({
      code: 'REVENUECAT_SYNC_CONFIGURATION',
      error: 'RevenueCat synchronization is not configured',
    });
    expect(result.body).not.toContain('secret-value');
    expect(result.body).not.toContain('Bearer');
  });

  it('rejects malformed JSON without reconciling', async () => {
    const reconcile = vi.fn();
    const handler = createSyncRevenueCatCustomerHandler({ reconcile });

    const result = await handler(event('{not-json'));

    expect(result.statusCode).toBe(400);
    expect(reconcile).not.toHaveBeenCalled();
  });
});
