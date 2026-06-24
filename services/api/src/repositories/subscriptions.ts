import type { UserPlan } from './user-profiles';

export type RevenueCatEntitlement = 'free' | 'pro';
export type RevenueCatNormalizedEvent = 'ACTIVE' | 'INACTIVE' | 'UNKNOWN';

export interface SubscriptionStateInput {
  userId: string;
  revenueCatAppUserId: string;
  plan: UserPlan;
  productId?: string | null;
  store?: string | null;
  periodType?: string | null;
  expiresAt?: string | null;
  lastEventAt?: string | null;
  rawCustomerInfo?: unknown;
}

export interface RevenueCatWebhookEventInput {
  eventId: string;
  appUserId: string;
  eventType: string;
  productId?: string | null;
  payload: unknown;
}

export function planFromRevenueCatEntitlements(entitlements: string[]): UserPlan {
  return entitlements.includes('pro') ? 'PRO' : 'FREE';
}

export function entitlementFromPlan(plan: UserPlan): RevenueCatEntitlement {
  return plan === 'PRO' ? 'pro' : 'free';
}

export function normalizeRevenueCatEventType(eventType: string): RevenueCatNormalizedEvent {
  if (['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION'].includes(eventType)) {
    return 'ACTIVE';
  }

  if (['EXPIRATION', 'CANCELLATION', 'BILLING_ISSUE', 'REFUND'].includes(eventType)) {
    return 'INACTIVE';
  }

  return 'UNKNOWN';
}

export async function updateUserPlan(userId: string, plan: UserPlan): Promise<void> {
  const [{ query }, { setUserPlan }] = await Promise.all([
    import('../db/client'),
    import('./user-profiles'),
  ]);

  await query('UPDATE users SET plan = $2 WHERE id = $1', [userId, plan]);
  await setUserPlan(userId, plan);
}

export async function upsertSubscriptionState(input: SubscriptionStateInput): Promise<void> {
  const { query } = await import('../db/client');

  await query(
    `
      INSERT INTO user_subscriptions (
        user_id, revenuecat_app_user_id, entitlement, plan, product_id, store,
        period_type, expires_at, last_event_at, raw_customer_info,
        last_synced_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, NOW(), NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        revenuecat_app_user_id = EXCLUDED.revenuecat_app_user_id,
        entitlement = EXCLUDED.entitlement,
        plan = EXCLUDED.plan,
        product_id = EXCLUDED.product_id,
        store = EXCLUDED.store,
        period_type = EXCLUDED.period_type,
        expires_at = EXCLUDED.expires_at,
        last_event_at = EXCLUDED.last_event_at,
        raw_customer_info = EXCLUDED.raw_customer_info,
        last_synced_at = NOW(),
        updated_at = NOW();
    `,
    [
      input.userId,
      input.revenueCatAppUserId,
      entitlementFromPlan(input.plan),
      input.plan,
      input.productId ?? null,
      input.store ?? null,
      input.periodType ?? null,
      input.expiresAt ?? null,
      input.lastEventAt ?? null,
      JSON.stringify(input.rawCustomerInfo ?? {}),
    ],
  );

  await updateUserPlan(input.userId, input.plan);
}

export async function recordRevenueCatWebhookEvent(
  input: RevenueCatWebhookEventInput,
): Promise<'created' | 'duplicate'> {
  const { query } = await import('../db/client');

  const result = await query<{ event_id: string }>(
    `
      INSERT INTO revenuecat_webhook_events (
        event_id, app_user_id, event_type, product_id, payload
      ) VALUES ($1, $2, $3, $4, $5::jsonb)
      ON CONFLICT (event_id) DO NOTHING
      RETURNING event_id;
    `,
    [
      input.eventId,
      input.appUserId,
      input.eventType,
      input.productId ?? null,
      JSON.stringify(input.payload),
    ],
  );

  return result.rows.length > 0 ? 'created' : 'duplicate';
}

export async function markRevenueCatWebhookProcessed(eventId: string): Promise<void> {
  const { query } = await import('../db/client');

  await query(
    `
      UPDATE revenuecat_webhook_events
      SET processed_at = NOW()
      WHERE event_id = $1;
    `,
    [eventId],
  );
}
