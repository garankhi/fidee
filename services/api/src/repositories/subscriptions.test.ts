import { describe, expect, it } from 'vitest';
import { normalizeRevenueCatEventType, planFromRevenueCatEntitlements } from './subscriptions';

describe('subscription helpers', () => {
  it('maps active pro entitlement to PRO', () => {
    expect(planFromRevenueCatEntitlements(['pro'])).toBe('PRO');
  });

  it('maps missing pro entitlement to FREE', () => {
    expect(planFromRevenueCatEntitlements(['other'])).toBe('FREE');
    expect(planFromRevenueCatEntitlements([])).toBe('FREE');
  });

  it('normalizes webhook event names', () => {
    expect(normalizeRevenueCatEventType('INITIAL_PURCHASE')).toBe('ACTIVE');
    expect(normalizeRevenueCatEventType('RENEWAL')).toBe('ACTIVE');
    expect(normalizeRevenueCatEventType('EXPIRATION')).toBe('INACTIVE');
    expect(normalizeRevenueCatEventType('CANCELLATION')).toBe('INACTIVE');
    expect(normalizeRevenueCatEventType('PRODUCT_CHANGE')).toBe('UNKNOWN');
  });
});
