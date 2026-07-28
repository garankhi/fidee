import type {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from 'aws-lambda';
import { timingSafeEqual } from 'crypto';
import {
  deleteExpiredPendingIdentityEvents,
  markRevenueCatWebhookProcessed,
  recordRevenueCatWebhookEvent,
  resolveKnownFideeUserIds,
  type RevenueCatWebhookEventInput,
  type RevenueCatWebhookRecord,
} from '../repositories/subscriptions';
import {
  reconcileRevenueCatCustomer,
  type ReconcileRevenueCatCustomerInput,
  type ReconciliationResult,
} from '../services/subscription-reconciler';
import { loadRevenueCatServerSecrets } from '../services/revenuecat-client';

interface RevenueCatWebhookDeps {
  loadAuthorization: () => Promise<string>;
  resolveUserIds: (candidateIds: string[]) => Promise<string[]>;
  recordEvent: (
    input: RevenueCatWebhookEventInput,
  ) => Promise<RevenueCatWebhookRecord>;
  reconcile: (
    input: ReconcileRevenueCatCustomerInput,
  ) => Promise<ReconciliationResult>;
  markProcessed: (
    eventId: string,
    resolvedUserIds: string[],
  ) => Promise<void>;
  deleteExpiredPendingIdentities: () => Promise<number>;
}

interface ParsedRevenueCatWebhookEvent {
  id: string;
  type: string;
  candidateAppUserIds: string[];
  productId: string | null;
  store: string | null;
  expiresAt: string | null;
  eventAt: string | null;
  payload: Record<string, unknown>;
}

const lifecycleEventTypes = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'CANCELLATION',
  'BILLING_ISSUE',
  'REFUND',
  'EXPIRATION',
  'PRODUCT_CHANGE',
  'TRANSFER',
]);

function jsonResponse(
  statusCode: number,
  body: Record<string, unknown>,
): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify(body),
  };
}

function headerValue(
  event: APIGatewayProxyEvent,
  name: string,
): string | undefined {
  const target = name.toLowerCase();
  for (const [key, value] of Object.entries(event.headers ?? {})) {
    if (key.toLowerCase() === target) return value;
  }
  return undefined;
}

function constantTimeEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return (
    leftBuffer.length === rightBuffer.length &&
    timingSafeEqual(leftBuffer, rightBuffer)
  );
}

function hasValidAuthorization(
  event: APIGatewayProxyEvent,
  expected: string,
): boolean {
  if (!expected) return false;
  const supplied =
    headerValue(event, 'authorization') ??
    headerValue(event, 'x-revenuecat-signature') ??
    '';
  return (
    constantTimeEqual(supplied, expected) ||
    constantTimeEqual(supplied, `Bearer ${expected}`)
  );
}

function timestampFromMs(value: unknown): string | null {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  return new Date(value).toISOString();
}

function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim()
    ? value.trim()
    : null;
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter(
      (item): item is string =>
        typeof item === 'string' && item.trim().length > 0,
    )
    .map((item) => item.trim());
}

function parseWebhookEvent(
  event: APIGatewayProxyEvent,
): ParsedRevenueCatWebhookEvent {
  let parsed: unknown;
  try {
    parsed = JSON.parse(event.body ?? '{}') as unknown;
  } catch {
    throw new SyntaxError('Request body must be valid JSON');
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new SyntaxError('Request body must be a JSON object');
  }

  const rawEvent = (parsed as Record<string, unknown>).event;
  if (
    typeof rawEvent !== 'object' ||
    rawEvent === null ||
    Array.isArray(rawEvent)
  ) {
    throw new SyntaxError('event is required');
  }

  const value = rawEvent as Record<string, unknown>;
  const id = optionalString(value.id);
  const type = optionalString(value.type);
  if (!id) throw new SyntaxError('event.id is required');
  if (!type) throw new SyntaxError('event.type is required');

  const aliases = stringArray(value.aliases);
  const transferredFrom = stringArray(value.transferred_from);
  const transferredTo = stringArray(value.transferred_to);
  const candidateAppUserIds = [
    ...new Set(
      [
        optionalString(value.app_user_id),
        optionalString(value.original_app_user_id),
        ...aliases,
        ...transferredFrom,
        ...transferredTo,
      ].filter((candidate): candidate is string => candidate !== null),
    ),
  ];
  if (candidateAppUserIds.length === 0) {
    throw new SyntaxError('event customer identity is required');
  }

  const productId = optionalString(value.product_id);
  const store = optionalString(value.store);
  const expiresAt = timestampFromMs(value.expiration_at_ms);
  const eventAt = timestampFromMs(value.event_timestamp_ms);

  return {
    id,
    type,
    candidateAppUserIds,
    productId,
    store,
    expiresAt,
    eventAt,
    payload: {
      eventId: id,
      eventType: type,
      productId,
      store,
      expiresAt,
      eventAt,
    },
  };
}

async function loadDefaultAuthorization(): Promise<string> {
  const secretArn = process.env.REVENUECAT_SERVER_SECRET_ARN?.trim();
  if (!secretArn) {
    throw new Error('RevenueCat server secret is not configured');
  }
  const secret = await loadRevenueCatServerSecrets(secretArn);
  if (!secret.webhookAuthorization) {
    throw new Error('RevenueCat webhook authorization is not configured');
  }
  return secret.webhookAuthorization;
}

function defaultDeps(): RevenueCatWebhookDeps {
  return {
    loadAuthorization: loadDefaultAuthorization,
    resolveUserIds: resolveKnownFideeUserIds,
    recordEvent: recordRevenueCatWebhookEvent,
    reconcile: reconcileRevenueCatCustomer,
    markProcessed: markRevenueCatWebhookProcessed,
    deleteExpiredPendingIdentities:
      deleteExpiredPendingIdentityEvents,
  };
}

export function createRevenueCatWebhookHandler(
  deps: RevenueCatWebhookDeps = defaultDeps(),
) {
  return async (
    event: APIGatewayProxyEvent,
  ): Promise<APIGatewayProxyResult> => {
    let expectedAuthorization: string;
    try {
      expectedAuthorization = await deps.loadAuthorization();
    } catch {
      console.error('RevenueCat webhook authorization is unavailable');
      return jsonResponse(500, { error: 'Webhook is not configured' });
    }

    if (!hasValidAuthorization(event, expectedAuthorization)) {
      return jsonResponse(401, { error: 'Unauthorized' });
    }

    try {
      await deps.deleteExpiredPendingIdentities();
      const parsed = parseWebhookEvent(event);
      const resolvedUserIds = await deps.resolveUserIds(
        parsed.candidateAppUserIds,
      );
      const record = await deps.recordEvent({
        eventId: parsed.id,
        eventType: parsed.type,
        candidateAppUserIds: parsed.candidateAppUserIds,
        resolvedUserIds,
        state: resolvedUserIds.length > 0 ? 'pending' : 'pending_identity',
        productId: parsed.productId,
        store: parsed.store,
        eventAt: parsed.eventAt,
        expiresAt: parsed.expiresAt,
        payload: parsed.payload,
      });

      if (record.state === 'processed') {
        return jsonResponse(200, { status: 'duplicate' });
      }

      const knownUserIds = [
        ...new Set([...record.resolvedUserIds, ...resolvedUserIds]),
      ];
      if (knownUserIds.length === 0) {
        return jsonResponse(200, { status: 'pending_identity' });
      }

      if (!lifecycleEventTypes.has(parsed.type)) {
        await deps.markProcessed(parsed.id, knownUserIds);
        return jsonResponse(200, { status: 'ignored' });
      }

      const results = await Promise.all(
        knownUserIds.map((knownUserId) =>
          deps.reconcile({
            userId: knownUserId,
            revenueCatCustomerId: knownUserId,
          }),
        ),
      );
      await deps.markProcessed(parsed.id, knownUserIds);

      return jsonResponse(200, {
        status: 'processed',
        ...(results.length === 1
          ? results[0]
          : { reconciliations: results }),
      });
    } catch (error) {
      if (error instanceof SyntaxError) {
        return jsonResponse(400, { error: error.message });
      }

      console.error('RevenueCat webhook reconciliation failed');
      return jsonResponse(503, {
        error: 'RevenueCat webhook reconciliation is temporarily unavailable',
      });
    }
  };
}

export const handler = createRevenueCatWebhookHandler();
