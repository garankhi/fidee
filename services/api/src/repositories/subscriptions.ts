import type { PoolClient } from 'pg';
import { query, withTransaction } from '../db/client';
import { setUserPlan, type UserPlan } from './user-profiles';

export type RevenueCatEntitlement = 'free' | 'pro';
export type RevenueCatNormalizedEvent = 'ACTIVE' | 'INACTIVE' | 'UNKNOWN';

export interface SubscriptionStateInput {
  userId: string;
  revenueCatAppUserId: string;
  revenueCatAliases?: string[];
  plan: UserPlan;
  verifiedAt?: string;
  productId?: string | null;
  store?: string | null;
  periodType?: string | null;
  expiresAt?: string | null;
  lastEventAt?: string | null;
  /** Accepted only for backward compatibility; authoritative reconciliation never persists it. */
  rawCustomerInfo?: unknown;
}

export type RevenueCatWebhookProcessingState =
  | 'pending_identity'
  | 'pending'
  | 'processed';

export interface RevenueCatWebhookRecord {
  eventId: string;
  state: RevenueCatWebhookProcessingState;
  resolvedUserIds: string[];
}

export interface RevenueCatWebhookEventInput {
  eventId: string;
  eventType: string;
  candidateAppUserIds: string[];
  resolvedUserIds: string[];
  state: Exclude<RevenueCatWebhookProcessingState, 'processed'>;
  productId?: string | null;
  store?: string | null;
  eventAt?: string | null;
  expiresAt?: string | null;
  payload: Record<string, unknown>;
}

export function planFromRevenueCatEntitlements(
  entitlements: string[],
): UserPlan {
  return entitlements.includes('pro') ? 'PRO' : 'FREE';
}

export function entitlementFromPlan(
  plan: UserPlan,
): RevenueCatEntitlement {
  return plan === 'PRO' ? 'pro' : 'free';
}

export function normalizeRevenueCatEventType(
  eventType: string,
): RevenueCatNormalizedEvent {
  if (['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION'].includes(eventType)) {
    return 'ACTIVE';
  }

  if (
    ['EXPIRATION', 'CANCELLATION', 'BILLING_ISSUE', 'REFUND'].includes(
      eventType,
    )
  ) {
    return 'INACTIVE';
  }

  return 'UNKNOWN';
}

async function persistWithClient(
  client: PoolClient,
  input: SubscriptionStateInput,
): Promise<void> {
  await client.query(
    `
      INSERT INTO user_subscriptions (
        user_id, revenuecat_app_user_id, revenuecat_aliases, entitlement,
        plan, product_id, store, period_type, expires_at, last_event_at,
        raw_customer_info, last_synced_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        '{}'::jsonb, $11::timestamptz, NOW()
      )
      ON CONFLICT (user_id) DO UPDATE SET
        revenuecat_app_user_id = EXCLUDED.revenuecat_app_user_id,
        revenuecat_aliases = EXCLUDED.revenuecat_aliases,
        entitlement = EXCLUDED.entitlement,
        plan = EXCLUDED.plan,
        product_id = EXCLUDED.product_id,
        store = EXCLUDED.store,
        period_type = EXCLUDED.period_type,
        expires_at = EXCLUDED.expires_at,
        last_event_at = EXCLUDED.last_event_at,
        raw_customer_info = '{}'::jsonb,
        last_synced_at = EXCLUDED.last_synced_at,
        updated_at = NOW();
    `,
    [
      input.userId,
      input.revenueCatAppUserId,
      [...new Set(input.revenueCatAliases ?? [])],
      entitlementFromPlan(input.plan),
      input.plan,
      input.productId ?? null,
      input.store ?? null,
      input.periodType ?? null,
      input.expiresAt ?? null,
      input.lastEventAt ?? null,
      input.verifiedAt ?? new Date().toISOString(),
    ],
  );

  await client.query('UPDATE users SET plan = $2 WHERE id = $1', [
    input.userId,
    input.plan,
  ]);
}

export async function persistSubscriptionState(
  input: SubscriptionStateInput,
  client?: PoolClient,
): Promise<void> {
  if (!client) {
    await withTransaction((transactionClient) =>
      persistWithClient(transactionClient, input),
    );
    return;
  }

  try {
    await client.query('BEGIN');
    await persistWithClient(client, input);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}

export async function resolveKnownFideeUserIds(
  candidateIds: string[],
): Promise<string[]> {
  const normalized = [
    ...new Set(candidateIds.map((id) => id.trim()).filter(Boolean)),
  ];
  if (normalized.length === 0) return [];

  const result = await query<{ id: string }>(
    `
      SELECT DISTINCT u.id
      FROM users u
      LEFT JOIN user_subscriptions s ON s.user_id = u.id
      WHERE u.id = ANY($1::text[])
         OR s.revenuecat_app_user_id = ANY($1::text[])
         OR s.revenuecat_aliases && $1::text[]
      ORDER BY u.id;
    `,
    [normalized],
  );

  return result.rows.map((row) => row.id);
}

export async function resolvePendingIdentityEvents(
  userId: string,
  knownRevenueCatIds: string[],
): Promise<number> {
  const normalized = [
    ...new Set(knownRevenueCatIds.map((id) => id.trim()).filter(Boolean)),
  ];
  if (normalized.length === 0) return 0;

  const result = await query(
    `
      UPDATE revenuecat_webhook_events
      SET resolved_user_ids = CASE
            WHEN $1 = ANY(resolved_user_ids) THEN resolved_user_ids
            ELSE array_append(resolved_user_ids, $1)
          END,
          processing_state = 'processed',
          processed_at = NOW()
      WHERE processing_state = 'pending_identity'
        AND candidate_app_user_ids && $2::text[];
    `,
    [userId, normalized],
  );

  return result.rowCount ?? 0;
}

/** Backward-compatible wrapper for already-released handler code. */
export async function upsertSubscriptionState(
  input: SubscriptionStateInput,
): Promise<void> {
  await persistSubscriptionState(input);
  await setUserPlan(input.userId, input.plan);
}

export async function updateUserPlan(
  userId: string,
  plan: UserPlan,
): Promise<void> {
  await withTransaction(async (client) => {
    await client.query('UPDATE users SET plan = $2 WHERE id = $1', [
      userId,
      plan,
    ]);
  });
  await setUserPlan(userId, plan);
}

export async function recordRevenueCatWebhookEvent(
  input: RevenueCatWebhookEventInput,
): Promise<RevenueCatWebhookRecord> {
  const candidateAppUserIds = [
    ...new Set(
      input.candidateAppUserIds
        .map((candidate) => candidate.trim())
        .filter(Boolean),
    ),
  ];
  const appUserId = candidateAppUserIds[0] ?? '';
  const resolvedUserIds = [
    ...new Set(input.resolvedUserIds.map((userId) => userId.trim()).filter(Boolean)),
  ];

  const result = await query<{
    event_id: string;
    processing_state: RevenueCatWebhookProcessingState;
    resolved_user_ids: string[];
  }>(
    `
      INSERT INTO revenuecat_webhook_events (
        event_id, app_user_id, event_type, product_id, payload,
        candidate_app_user_ids, resolved_user_ids, processing_state,
        retention_expires_at
      ) VALUES (
        $1, $2, $3, $4, $5::jsonb, $6, $7, $8,
        NOW() + INTERVAL '30 days'
      )
      ON CONFLICT (event_id) DO UPDATE SET
        resolved_user_ids = ARRAY(
          SELECT DISTINCT resolved_id
          FROM unnest(
            revenuecat_webhook_events.resolved_user_ids ||
            EXCLUDED.resolved_user_ids
          ) AS resolved_id
        ),
        processing_state = CASE
          WHEN revenuecat_webhook_events.processing_state = 'pending_identity'
            AND cardinality(EXCLUDED.resolved_user_ids) > 0
          THEN 'pending'
          ELSE revenuecat_webhook_events.processing_state
        END
      RETURNING event_id, processing_state, resolved_user_ids;
    `,
    [
      input.eventId,
      appUserId,
      input.eventType,
      input.productId ?? null,
      JSON.stringify(input.payload),
      candidateAppUserIds,
      resolvedUserIds,
      input.state,
    ],
  );

  const row = result.rows[0];
  if (!row) throw new Error('RevenueCat webhook event was not recorded');

  return {
    eventId: row.event_id,
    state: row.processing_state,
    resolvedUserIds: [...new Set(row.resolved_user_ids ?? [])],
  };
}

export async function markRevenueCatWebhookProcessed(
  eventId: string,
  resolvedUserIds: string[],
): Promise<void> {
  await query(
    `
      UPDATE revenuecat_webhook_events
      SET processed_at = NOW(),
          processing_state = 'processed',
          resolved_user_ids = $2
      WHERE event_id = $1;
    `,
    [eventId, [...new Set(resolvedUserIds)]],
  );
}

export async function deleteExpiredPendingIdentityEvents(): Promise<number> {
  const result = await query(
    `
      DELETE FROM revenuecat_webhook_events
      WHERE processing_state = 'pending_identity'
        AND retention_expires_at <= NOW();
    `,
  );

  return result.rowCount ?? 0;
}
