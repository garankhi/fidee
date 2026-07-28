import { describe, expect, it, vi } from 'vitest';
import {
  createRevenueCatClient,
  RevenueCatVerificationError,
  type RevenueCatClientConfig,
} from './revenuecat-client';

const config: RevenueCatClientConfig = {
  projectId: 'proj_test',
  proEntitlementId: 'entl_pro',
  serverSecretArn: 'arn:aws:secretsmanager:region:account:secret:test',
  timeoutMs: 20,
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function list(items: unknown[], nextPage: string | null = null) {
  return {
    object: 'list',
    items,
    next_page: nextPage,
    url: '/v2/test',
  };
}

describe('RevenueCat v2 client', () => {
  it('maps the configured active entitlement to PRO and returns aliases', async () => {
    const fetchFn = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        jsonResponse(
          list([
            {
              object: 'customer.active_entitlement',
              entitlement_id: 'entl_pro',
              expires_at: 1_800_000_000_000,
            },
          ]),
        ),
      )
      .mockResolvedValueOnce(
        jsonResponse(
          list([
            {
              object: 'customer.alias',
              id: '$RCAnonymousID:old',
              created_at: 1_700_000_000_000,
            },
          ]),
        ),
      );

    const client = createRevenueCatClient({
      config,
      fetchFn,
      loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
      now: () => new Date('2026-07-28T10:00:00.000Z'),
    });

    await expect(client.verifyCustomer('user-123')).resolves.toEqual({
      customerId: 'user-123',
      plan: 'PRO',
      aliases: ['$RCAnonymousID:old'],
      activeEntitlementIds: ['entl_pro'],
      verifiedAt: '2026-07-28T10:00:00.000Z',
    });
    expect(fetchFn).toHaveBeenCalledTimes(2);
    expect(fetchFn.mock.calls[0]?.[1]?.headers).toEqual({
      Authorization: 'Bearer secret-key',
      'Content-Type': 'application/json',
    });
  });

  it('loads entitlements and aliases concurrently within one verification deadline', async () => {
    let releaseEntitlements: (() => void) | undefined;
    const fetchFn = vi.fn<typeof fetch>().mockImplementation(async (input) => {
      const url = String(input);
      if (url.includes('/active_entitlements')) {
        await new Promise<void>((resolve) => {
          releaseEntitlements = resolve;
        });
        return jsonResponse(list([]));
      }

      releaseEntitlements?.();
      return jsonResponse(list([]));
    });

    const verification = createRevenueCatClient({
      config: { ...config, timeoutMs: 1000 },
      fetchFn,
      loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
    }).verifyCustomer('user-123');

    const result = await Promise.race([
      verification,
      new Promise<'timed-out'>((resolve) =>
        setTimeout(() => resolve('timed-out'), 50),
      ),
    ]);

    expect(result).not.toBe('timed-out');
    expect(fetchFn).toHaveBeenCalledTimes(2);
  });

  it('maps a successful empty active entitlement list to FREE', async () => {
    const fetchFn = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(jsonResponse(list([])))
      .mockResolvedValueOnce(jsonResponse(list([])));

    const result = await createRevenueCatClient({
      config,
      fetchFn,
      loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
    }).verifyCustomer('user-123');

    expect(result.plan).toBe('FREE');
    expect(result.activeEntitlementIds).toEqual([]);
  });

  it('URL-encodes the Cognito subject', async () => {
    const fetchFn = vi
      .fn<typeof fetch>()
      .mockImplementation(async () => jsonResponse(list([])));

    await createRevenueCatClient({
      config,
      fetchFn,
      loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
    }).verifyCustomer('user/with space');

    expect(String(fetchFn.mock.calls[0]?.[0])).toContain(
      '/customers/user%2Fwith%20space/active_entitlements?limit=100',
    );
  });

  it('follows next_page with a hard maximum of five pages', async () => {
    const fetchFn = vi.fn<typeof fetch>().mockImplementation(async (input) => {
      const url = String(input);
      if (url.includes('/aliases')) return jsonResponse(list([]));
      return jsonResponse(
        list(
          [],
          '/v2/projects/proj_test/customers/user-123/active_entitlements?starting_after=next',
        ),
      );
    });

    await expect(
      createRevenueCatClient({
        config,
        fetchFn,
        loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
      }).verifyCustomer('user-123'),
    ).rejects.toMatchObject({
      kind: 'retryable',
      statusCode: null,
    });
    const entitlementCalls = fetchFn.mock.calls.filter(([input]) =>
      String(input).includes('/active_entitlements'),
    );
    const aliasCalls = fetchFn.mock.calls.filter(([input]) =>
      String(input).includes('/aliases'),
    );
    expect(entitlementCalls).toHaveLength(5);
    expect(aliasCalls).toHaveLength(1);
  });

  it.each([401, 403])(
    'classifies status %s as a configuration failure',
    async (status) => {
      const client = createRevenueCatClient({
        config,
        fetchFn: vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, status)),
        loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
      });

      await expect(client.verifyCustomer('user-123')).rejects.toMatchObject({
        kind: 'configuration',
        statusCode: status,
      });
    },
  );

  it.each([429, 500, 503])(
    'classifies status %s as a retryable failure',
    async (status) => {
      const client = createRevenueCatClient({
        config,
        fetchFn: vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, status)),
        loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
      });

      await expect(client.verifyCustomer('user-123')).rejects.toMatchObject({
        kind: 'retryable',
        statusCode: status,
      });
    },
  );

  it('classifies malformed successful payloads as retryable', async () => {
    const client = createRevenueCatClient({
      config,
      fetchFn: vi
        .fn<typeof fetch>()
        .mockResolvedValue(jsonResponse({ object: 'list', items: 'invalid' })),
      loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
    });

    await expect(client.verifyCustomer('user-123')).rejects.toBeInstanceOf(
      RevenueCatVerificationError,
    );
    await expect(client.verifyCustomer('user-123')).rejects.toMatchObject({
      kind: 'retryable',
      statusCode: 200,
    });
  });

  it('aborts a timed-out request and classifies it as retryable', async () => {
    const fetchFn = vi.fn<typeof fetch>().mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener('abort', () => {
            reject(new DOMException('aborted', 'AbortError'));
          });
        }),
    );

    const client = createRevenueCatClient({
      config: { ...config, timeoutMs: 1 },
      fetchFn,
      loadSecrets: async () => ({ apiV2Key: 'secret-key' }),
    });

    await expect(client.verifyCustomer('user-123')).rejects.toMatchObject({
      kind: 'retryable',
      statusCode: null,
    });
  });

  it('never exposes secrets, authorization headers, or full payloads in errors', async () => {
    const secret = 'never-print-this';
    const payload = { private_customer_value: 'never-print-payload' };
    const client = createRevenueCatClient({
      config,
      fetchFn: vi.fn<typeof fetch>().mockResolvedValue(jsonResponse(payload, 500)),
      loadSecrets: async () => ({ apiV2Key: secret }),
    });

    const error = await client.verifyCustomer('user-123').catch((value) => value);

    expect(String(error)).not.toContain(secret);
    expect(String(error)).not.toContain('Authorization');
    expect(String(error)).not.toContain(JSON.stringify(payload));
  });
});
