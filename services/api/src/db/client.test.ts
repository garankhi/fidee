import type { PoolClient } from 'pg';
import { describe, expect, it, vi } from 'vitest';
import { withUserReconciliationLock } from './client';

function fakeClient() {
  const query = vi.fn().mockResolvedValue({ rows: [], rowCount: 0 });
  const release = vi.fn();
  return {
    client: { query, release } as unknown as PoolClient,
    query,
    release,
  };
}

describe('withUserReconciliationLock', () => {
  it('holds a transaction advisory lock around reconciliation work', async () => {
    const { client, query, release } = fakeClient();
    const events: string[] = [];

    const result = await withUserReconciliationLock(
      'user-1',
      async (lockedClient) => {
        expect(lockedClient).toBe(client);
        events.push('work');
        return 42;
      },
      async () => client,
    );

    expect(result).toBe(42);
    expect(query.mock.calls[0][0]).toContain('pg_advisory_lock');
    expect(query.mock.calls[0][1]).toEqual(['user-1']);
    expect(query.mock.calls[1][0]).toContain('pg_advisory_unlock');
    expect(query.mock.calls[1][1]).toEqual(['user-1']);
    expect(events).toEqual(['work']);
    expect(release).toHaveBeenCalledOnce();
  });

  it('rolls back and releases the connection when reconciliation fails', async () => {
    const { client, query, release } = fakeClient();

    await expect(
      withUserReconciliationLock(
        'user-1',
        async () => {
          throw new Error('verification failed');
        },
        async () => client,
      ),
    ).rejects.toThrow('verification failed');

    expect(query.mock.calls.at(-1)?.[0]).toContain('pg_advisory_unlock');
    expect(release).toHaveBeenCalledOnce();
  });

  it('destroys the connection when advisory unlock fails', async () => {
    const { client, query, release } = fakeClient();
    query
      .mockResolvedValueOnce({ rows: [], rowCount: 1 })
      .mockRejectedValueOnce(new Error('unlock failed'));

    await expect(
      withUserReconciliationLock(
        'user-1',
        async () => 42,
        async () => client,
      ),
    ).rejects.toThrow('unlock failed');

    expect(release).toHaveBeenCalledWith(true);
  });
});
