import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { extractAuth } from '../middleware/auth';
import {
  entitlementFromPlan,
  planFromRevenueCatEntitlements,
  upsertSubscriptionState,
} from '../repositories/subscriptions';

interface SyncRevenueCatCustomerDeps {
  syncSubscription: typeof upsertSubscriptionState;
}

interface SyncRevenueCatBody {
  appUserId: string;
  activeEntitlementIds: string[];
  productId?: string | null;
  store?: string | null;
  expiresAt?: string | null;
  customerInfo?: unknown;
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

function parseBody(event: APIGatewayProxyEvent): SyncRevenueCatBody {
  let value: unknown;
  try {
    value = JSON.parse(event.body ?? '{}') as unknown;
  } catch {
    throw new Error('Request body must be valid JSON');
  }

  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('Request body must be a JSON object');
  }

  const body = value as Record<string, unknown>;
  const appUserId = body.appUserId;
  if (typeof appUserId !== 'string' || appUserId.trim().length === 0) {
    throw new Error('appUserId is required');
  }

  const activeEntitlementIds = Array.isArray(body.activeEntitlementIds)
    ? body.activeEntitlementIds.filter((id): id is string => typeof id === 'string')
    : [];

  return {
    appUserId: appUserId.trim(),
    activeEntitlementIds,
    productId: typeof body.productId === 'string' ? body.productId : null,
    store: typeof body.store === 'string' ? body.store : null,
    expiresAt: typeof body.expiresAt === 'string' ? body.expiresAt : null,
    customerInfo: body.customerInfo,
  };
}

export function createSyncRevenueCatCustomerHandler(
  deps: SyncRevenueCatCustomerDeps = { syncSubscription: upsertSubscriptionState },
) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
      const auth = await extractAuth(event);
      const body = parseBody(event);

      if (body.appUserId !== auth.sub) {
        return jsonResponse(403, { error: 'appUserId must match authenticated user' });
      }

      const plan = planFromRevenueCatEntitlements(body.activeEntitlementIds);
      await deps.syncSubscription({
        userId: auth.sub,
        revenueCatAppUserId: body.appUserId,
        plan,
        productId: body.productId,
        store: body.store,
        expiresAt: body.expiresAt,
        rawCustomerInfo: body.customerInfo,
      });

      return jsonResponse(200, {
        plan,
        entitlement: entitlementFromPlan(plan),
      });
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('Missing auth context')) {
        return jsonResponse(401, { error: error.message });
      }
      if (error instanceof Error && error.message.includes('JSON')) {
        return jsonResponse(400, { error: error.message });
      }
      if (error instanceof Error && error.message.includes('appUserId')) {
        return jsonResponse(400, { error: error.message });
      }

      console.error('Failed to sync RevenueCat customer', error);
      return jsonResponse(500, { error: 'Internal server error' });
    }
  };
}

export const handler = createSyncRevenueCatCustomerHandler();
