import type { PoolClient } from 'pg';
import { describe, expect, it, vi } from 'vitest';
import {
  reconcileRevenueCatCustomer,
  type ReconcilerDeps,
} from './subscription-reconciler';

const lockClient = {} as PoolClient;

function verified(plan: 'FREE' | 'PRO') {
  return {
    customerId: 'user-1',
    plan,
    aliases: ['$RCAnonymousID:old'],
    activeEntitlementIds: plan === 'PRO' ? ['entl_pro'] : [],
    verifiedAt: '2026-07-28T10:00:00.000Z',
  };
}

function setup(plan: 'FREE' | 'PRO' = 'PRO') {
  const calls: string[] = [];
  const deps: ReconcilerDeps = {
    verifyCustomer: vi.fn(async () => {
      calls.push('verify');
      return verified(plan);
    }),
    persistSubscriptionState: vi.fn(async () => {
      calls.push('postgres');
    }),
    setUserPlan: vi.fn(async () => {
      calls.push('dynamodb');
    }),
    resolvePendingIdentityEvents: vi.fn(async () => {
      calls.push('pending-identities');
      return 1;
    }),
    withUserLock: vi.fn(
      async <T>(
        _userId: string,
        work: (client: PoolClient) => Promise<T>,
      ) => work(lockClient),
    ),
  };
  return { calls, deps };
}

describe('subscription reconciler', () => {
  it('writes PostgreSQL before DynamoDB and resolves pending identities last', async () => {
    const { calls, deps } = setup('PRO');

    await expect(
      reconcileRevenueCatCustomer(
        { userId: 'user-1', revenueCatCustomerId: 'user-1' },
        deps,
      ),
    ).resolves.toEqual({
      plan: 'PRO',
      entitlement: 'pro',
      reconciledAt: '2026-07-28T10:00:00.000Z',
    });

    expect(calls).toEqual([
      'verify',
      'postgres',
      'dynamodb',
      'pending-identities',
    ]);
    expect(deps.persistSubscriptionState).toHaveBeenCalledWith({
      userId: 'user-1',
      revenueCatAppUserId: 'user-1',
      revenueCatAliases: ['$RCAnonymousID:old'],
      plan: 'PRO',
      verifiedAt: '2026-07-28T10:00:00.000Z',
    }, lockClient);
    expect(deps.resolvePendingIdentityEvents).toHaveBeenCalledWith(
      'user-1',
      ['user-1', '$RCAnonymousID:old'],
    );
  });

  it('does not write DynamoDB when PostgreSQL persistence fails', async () => {
    const { deps } = setup();
    vi.mocked(deps.persistSubscriptionState).mockRejectedValueOnce(
      new Error('postgres failed'),
    );

    await expect(
      reconcileRevenueCatCustomer(
        { userId: 'user-1', revenueCatCustomerId: 'user-1' },
        deps,
      ),
    ).rejects.toThrow('postgres failed');
    expect(deps.setUserPlan).not.toHaveBeenCalled();
  });

  it('reports DynamoDB failure after PostgreSQL succeeds', async () => {
    const { deps } = setup();
    vi.mocked(deps.setUserPlan).mockRejectedValueOnce(
      new Error('dynamo failed'),
    );

    await expect(
      reconcileRevenueCatCustomer(
        { userId: 'user-1', revenueCatCustomerId: 'user-1' },
        deps,
      ),
    ).rejects.toThrow('dynamo failed');
    expect(deps.persistSubscriptionState).toHaveBeenCalledOnce();
    expect(deps.resolvePendingIdentityEvents).not.toHaveBeenCalled();
  });

  it('repeats the idempotent PostgreSQL write and repairs DynamoDB on retry', async () => {
    const { deps } = setup();
    vi.mocked(deps.setUserPlan)
      .mockRejectedValueOnce(new Error('dynamo failed'))
      .mockResolvedValueOnce(undefined);

    await expect(
      reconcileRevenueCatCustomer(
        { userId: 'user-1', revenueCatCustomerId: 'user-1' },
        deps,
      ),
    ).rejects.toThrow('dynamo failed');
    await expect(
      reconcileRevenueCatCustomer(
        { userId: 'user-1', revenueCatCustomerId: 'user-1' },
        deps,
      ),
    ).resolves.toMatchObject({ plan: 'PRO' });

    expect(deps.persistSubscriptionState).toHaveBeenCalledTimes(2);
    expect(deps.setUserPlan).toHaveBeenCalledTimes(2);
  });

  it('serializes overlapping reconciliations for the same user', async () => {
    const { deps } = setup('PRO');
    let lockTail = Promise.resolve();
    let activeVerifications = 0;
    let maximumConcurrentVerifications = 0;

    const withUserLock = vi.fn(
      async <T>(
        _userId: string,
        work: (client: PoolClient) => Promise<T>,
      ): Promise<T> => {
        const previous = lockTail;
        let releaseLock!: () => void;
        lockTail = new Promise<void>((resolve) => {
          releaseLock = resolve;
        });
        await previous;
        try {
          return await work(lockClient);
        } finally {
          releaseLock();
        }
      },
    );
    deps.withUserLock = withUserLock;
    vi.mocked(deps.verifyCustomer).mockImplementation(async () => {
      activeVerifications += 1;
      maximumConcurrentVerifications = Math.max(
        maximumConcurrentVerifications,
        activeVerifications,
      );
      await new Promise<void>((resolve) => setTimeout(resolve, 5));
      activeVerifications -= 1;
      return verified('PRO');
    });

    await Promise.all([
      reconcileRevenueCatCustomer(
        { userId: 'user-1', revenueCatCustomerId: 'user-1' },
        deps,
      ),
      reconcileRevenueCatCustomer(
        { userId: 'user-1', revenueCatCustomerId: 'user-1' },
        deps,
      ),
    ]);

    expect(maximumConcurrentVerifications).toBe(1);
    expect(withUserLock).toHaveBeenCalledTimes(2);
  });

  it('writes FREE only after a successful verified inactive response', async () => {
    const { deps } = setup('FREE');

    await reconcileRevenueCatCustomer(
      { userId: 'user-1', revenueCatCustomerId: 'user-1' },
      deps,
    );

    expect(deps.setUserPlan).toHaveBeenCalledWith('user-1', 'FREE');
  });
});
