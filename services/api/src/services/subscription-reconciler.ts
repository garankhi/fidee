import type { PoolClient } from 'pg';
import { withUserReconciliationLock } from '../db/client';
import {
  persistSubscriptionState,
  resolvePendingIdentityEvents,
  type SubscriptionStateInput,
} from '../repositories/subscriptions';
import {
  setUserPlan,
  type UserPlan,
} from '../repositories/user-profiles';
import {
  verifyRevenueCatCustomer,
  type VerifiedRevenueCatCustomer,
} from './revenuecat-client';

export interface ReconciliationResult {
  plan: UserPlan;
  entitlement: 'free' | 'pro';
  reconciledAt: string;
}

export interface ReconcileRevenueCatCustomerInput {
  userId: string;
  revenueCatCustomerId: string;
}

export interface ReconcilerDeps {
  verifyCustomer: (
    customerId: string,
  ) => Promise<VerifiedRevenueCatCustomer>;
  persistSubscriptionState: (
    input: SubscriptionStateInput,
    client?: PoolClient,
  ) => Promise<void>;
  setUserPlan: (userId: string, plan: UserPlan) => Promise<void>;
  resolvePendingIdentityEvents: (
    userId: string,
    knownRevenueCatIds: string[],
  ) => Promise<number>;
  withUserLock: <T>(
    userId: string,
    work: (client: PoolClient) => Promise<T>,
  ) => Promise<T>;
}

function defaultReconcilerDeps(): ReconcilerDeps {
  return {
    verifyCustomer: verifyRevenueCatCustomer,
    persistSubscriptionState,
    setUserPlan,
    resolvePendingIdentityEvents,
    withUserLock: withUserReconciliationLock,
  };
}

export async function reconcileRevenueCatCustomer(
  input: ReconcileRevenueCatCustomerInput,
  deps: ReconcilerDeps = defaultReconcilerDeps(),
): Promise<ReconciliationResult> {
  return deps.withUserLock(input.userId, async (client) => {
    const verified = await deps.verifyCustomer(
      input.revenueCatCustomerId,
    );

    await deps.persistSubscriptionState({
      userId: input.userId,
      revenueCatAppUserId: input.revenueCatCustomerId,
      revenueCatAliases: verified.aliases,
      plan: verified.plan,
      verifiedAt: verified.verifiedAt,
    }, client);

    await deps.setUserPlan(input.userId, verified.plan);

    await deps.resolvePendingIdentityEvents(input.userId, [
      input.revenueCatCustomerId,
      ...verified.aliases,
    ]);

    return {
      plan: verified.plan,
      entitlement: verified.plan === 'PRO' ? 'pro' : 'free',
      reconciledAt: verified.verifiedAt,
    };
  });
}
