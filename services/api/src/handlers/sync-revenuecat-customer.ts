import type {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from 'aws-lambda';
import { extractAuth } from '../middleware/auth';
import {
  reconcileRevenueCatCustomer,
  type ReconcileRevenueCatCustomerInput,
  type ReconciliationResult,
} from '../services/subscription-reconciler';
import { RevenueCatVerificationError } from '../services/revenuecat-client';

interface SyncRevenueCatCustomerDeps {
  reconcile: (
    input: ReconcileRevenueCatCustomerInput,
  ) => Promise<ReconciliationResult>;
}

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

function parseOptionalLegacyBody(event: APIGatewayProxyEvent): void {
  let value: unknown;
  try {
    value = JSON.parse(event.body ?? '{}') as unknown;
  } catch {
    throw new SyntaxError('Request body must be valid JSON');
  }

  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new SyntaxError('Request body must be a JSON object');
  }
}

export function createSyncRevenueCatCustomerHandler(
  deps: SyncRevenueCatCustomerDeps = {
    reconcile: reconcileRevenueCatCustomer,
  },
) {
  return async (
    event: APIGatewayProxyEvent,
  ): Promise<APIGatewayProxyResult> => {
    try {
      const auth = await extractAuth(event);
      parseOptionalLegacyBody(event);

      const result = await deps.reconcile({
        userId: auth.sub,
        revenueCatCustomerId: auth.sub,
      });

      return jsonResponse(200, { ...result });
    } catch (error) {
      if (
        error instanceof Error &&
        error.message.startsWith('Missing auth context')
      ) {
        return jsonResponse(401, { error: error.message });
      }

      if (error instanceof SyntaxError) {
        return jsonResponse(400, { error: error.message });
      }

      if (error instanceof RevenueCatVerificationError) {
        if (error.kind === 'configuration') {
          return jsonResponse(500, {
            code: 'REVENUECAT_SYNC_CONFIGURATION',
            error: 'RevenueCat synchronization is not configured',
          });
        }

        return jsonResponse(503, {
          code: 'REVENUECAT_SYNC_RETRYABLE',
          error: 'RevenueCat synchronization is temporarily unavailable',
        });
      }

      console.error('RevenueCat synchronization failed');
      return jsonResponse(503, {
        code: 'REVENUECAT_SYNC_RETRYABLE',
        error: 'RevenueCat synchronization is temporarily unavailable',
      });
    }
  };
}

export const handler = createSyncRevenueCatCustomerHandler();
