import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  entitlementFromPlan,
  markRevenueCatWebhookProcessed,
  normalizeRevenueCatEventType,
  recordRevenueCatWebhookEvent,
  SubscriptionStateInput,
  upsertSubscriptionState,
} from '../repositories/subscriptions';
import type { UserPlan } from '../repositories/user-profiles';

interface RevenueCatWebhookDeps {
  env: {
    webhookSecret: string;
  };
  recordEvent: typeof recordRevenueCatWebhookEvent;
  syncSubscription: typeof upsertSubscriptionState;
  markProcessed: typeof markRevenueCatWebhookProcessed;
}

interface RevenueCatWebhookEvent {
  id: string;
  type: string;
  appUserId: string;
  productId?: string | null;
  store?: string | null;
  periodType?: string | null;
  expiresAt?: string | null;
  eventAt?: string | null;
  raw: unknown;
}

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify(body),
  };
}

function headerValue(event: APIGatewayProxyEvent, name: string): string | undefined {
  const target = name.toLowerCase();
  for (const [key, value] of Object.entries(event.headers ?? {})) {
    if (key.toLowerCase() === target) return value;
  }
  return undefined;
}

function hasValidSecret(event: APIGatewayProxyEvent, secret: string): boolean {
  if (!secret) return false;
  const authorization = headerValue(event, 'authorization');
  if (authorization === `Bearer ${secret}`) return true;

  const signature = headerValue(event, 'x-revenuecat-signature');
  return signature === secret;
}

function timestampFromMs(value: unknown): string | null {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  return new Date(value).toISOString();
}

function parseWebhookEvent(event: APIGatewayProxyEvent): RevenueCatWebhookEvent {
  let parsed: unknown;
  try {
    parsed = JSON.parse(event.body ?? '{}') as unknown;
  } catch {
    throw new Error('Request body must be valid JSON');
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new Error('Request body must be a JSON object');
  }

  const body = parsed as Record<string, unknown>;
  const rawEvent = body.event;
  if (typeof rawEvent !== 'object' || rawEvent === null || Array.isArray(rawEvent)) {
    throw new Error('event is required');
  }

  const revenueCatEvent = rawEvent as Record<string, unknown>;
  const id = revenueCatEvent.id;
  const type = revenueCatEvent.type;
  const appUserId = revenueCatEvent.app_user_id;
  if (typeof id !== 'string' || id.trim().length === 0) {
    throw new Error('event.id is required');
  }
  if (typeof type !== 'string' || type.trim().length === 0) {
    throw new Error('event.type is required');
  }
  if (typeof appUserId !== 'string' || appUserId.trim().length === 0) {
    throw new Error('event.app_user_id is required');
  }

  return {
    id: id.trim(),
    type: type.trim(),
    appUserId: appUserId.trim(),
    productId: typeof revenueCatEvent.product_id === 'string' ? revenueCatEvent.product_id : null,
    store: typeof revenueCatEvent.store === 'string' ? revenueCatEvent.store : null,
    periodType:
      typeof revenueCatEvent.period_type === 'string' ? revenueCatEvent.period_type : null,
    expiresAt: timestampFromMs(revenueCatEvent.expiration_at_ms),
    eventAt: timestampFromMs(revenueCatEvent.event_timestamp_ms),
    raw: parsed,
  };
}

function planFromWebhookType(eventType: string): UserPlan | null {
  const normalized = normalizeRevenueCatEventType(eventType);
  if (normalized === 'ACTIVE') return 'PRO';
  if (normalized === 'INACTIVE') return 'FREE';
  return null;
}

function defaultDeps(): RevenueCatWebhookDeps {
  return {
    env: { webhookSecret: process.env.REVENUECAT_WEBHOOK_SECRET ?? '' },
    recordEvent: recordRevenueCatWebhookEvent,
    syncSubscription: upsertSubscriptionState,
    markProcessed: markRevenueCatWebhookProcessed,
  };
}

export function createRevenueCatWebhookHandler(deps: RevenueCatWebhookDeps = defaultDeps()) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    if (!hasValidSecret(event, deps.env.webhookSecret)) {
      return jsonResponse(401, { error: 'Unauthorized' });
    }

    try {
      const revenueCatEvent = parseWebhookEvent(event);
      const recordStatus = await deps.recordEvent({
        eventId: revenueCatEvent.id,
        appUserId: revenueCatEvent.appUserId,
        eventType: revenueCatEvent.type,
        productId: revenueCatEvent.productId,
        payload: revenueCatEvent.raw,
      });

      if (recordStatus === 'duplicate') {
        return jsonResponse(200, { status: 'duplicate' });
      }

      const plan = planFromWebhookType(revenueCatEvent.type);
      if (plan === null) {
        await deps.markProcessed(revenueCatEvent.id);
        return jsonResponse(200, { status: 'ignored' });
      }

      const subscriptionState: SubscriptionStateInput = {
        userId: revenueCatEvent.appUserId,
        revenueCatAppUserId: revenueCatEvent.appUserId,
        plan,
        productId: revenueCatEvent.productId,
        store: revenueCatEvent.store,
        periodType: revenueCatEvent.periodType,
        expiresAt: revenueCatEvent.expiresAt,
        lastEventAt: revenueCatEvent.eventAt,
        rawCustomerInfo: revenueCatEvent.raw,
      };
      await deps.syncSubscription(subscriptionState);
      await deps.markProcessed(revenueCatEvent.id);

      return jsonResponse(200, {
        status: 'processed',
        plan,
        entitlement: entitlementFromPlan(plan),
      });
    } catch (error) {
      if (error instanceof Error && error.message.includes('required')) {
        return jsonResponse(400, { error: error.message });
      }
      if (error instanceof Error && error.message.includes('JSON')) {
        return jsonResponse(400, { error: error.message });
      }

      console.error('Failed to process RevenueCat webhook', error);
      return jsonResponse(500, { error: 'Internal server error' });
    }
  };
}

export const handler = createRevenueCatWebhookHandler();
