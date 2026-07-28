import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from '@aws-sdk/client-secrets-manager';

export type VerifiedRevenueCatPlan = 'FREE' | 'PRO';

export interface VerifiedRevenueCatCustomer {
  customerId: string;
  plan: VerifiedRevenueCatPlan;
  aliases: string[];
  activeEntitlementIds: string[];
  verifiedAt: string;
}

export type RevenueCatFailureKind = 'retryable' | 'configuration';

export class RevenueCatVerificationError extends Error {
  constructor(
    public readonly kind: RevenueCatFailureKind,
    public readonly statusCode: number | null,
    message: string,
  ) {
    super(message);
    this.name = 'RevenueCatVerificationError';
  }
}

export interface RevenueCatClientConfig {
  projectId: string;
  proEntitlementId: string;
  serverSecretArn: string;
  timeoutMs: number;
}

export interface RevenueCatSecrets {
  apiV2Key: string;
  webhookAuthorization?: string;
}

export interface RevenueCatClientDeps {
  config: RevenueCatClientConfig;
  fetchFn?: typeof fetch;
  loadSecrets?: (secretArn: string) => Promise<RevenueCatSecrets>;
  now?: () => Date;
}

export interface RevenueCatClient {
  verifyCustomer(customerId: string): Promise<VerifiedRevenueCatCustomer>;
}

interface RevenueCatList {
  items: Record<string, unknown>[];
  nextPage: string | null;
}

const revenueCatApiBaseUrl = 'https://api.revenuecat.com';
const maximumPageCount = 5;
const secretsManager = new SecretsManagerClient({});
let cachedDefaultSecrets: Promise<RevenueCatSecrets> | null = null;

function configurationError(message: string): RevenueCatVerificationError {
  return new RevenueCatVerificationError('configuration', null, message);
}

function retryableError(
  message: string,
  statusCode: number | null = null,
): RevenueCatVerificationError {
  return new RevenueCatVerificationError('retryable', statusCode, message);
}

function configFromEnvironment(): RevenueCatClientConfig {
  const timeoutValue = Number(process.env.REVENUECAT_TIMEOUT_MS ?? '5000');
  return {
    projectId: process.env.REVENUECAT_PROJECT_ID?.trim() ?? '',
    proEntitlementId:
      process.env.REVENUECAT_PRO_ENTITLEMENT_ID?.trim() ?? '',
    serverSecretArn:
      process.env.REVENUECAT_SERVER_SECRET_ARN?.trim() ?? '',
    timeoutMs: timeoutValue,
  };
}

function validateConfig(config: RevenueCatClientConfig): void {
  if (
    !config.projectId ||
    !config.proEntitlementId ||
    !config.serverSecretArn ||
    !Number.isFinite(config.timeoutMs) ||
    config.timeoutMs <= 0
  ) {
    throw configurationError('RevenueCat server configuration is incomplete.');
  }
}

export async function loadRevenueCatServerSecrets(
  secretArn: string,
): Promise<RevenueCatSecrets> {
  cachedDefaultSecrets ??= (async (): Promise<RevenueCatSecrets> => {
    const response = await secretsManager.send(
      new GetSecretValueCommand({ SecretId: secretArn }),
    );
    if (!response.SecretString) {
      throw configurationError('RevenueCat server secret is unavailable.');
    }

    try {
      const value = JSON.parse(response.SecretString) as Record<string, unknown>;
      if (
        typeof value.apiV2Key !== 'string' ||
        value.apiV2Key.trim().length === 0
      ) {
        throw configurationError(
          'RevenueCat server secret is missing apiV2Key.',
        );
      }
      return {
        apiV2Key: value.apiV2Key.trim(),
        webhookAuthorization:
          typeof value.webhookAuthorization === 'string'
            ? value.webhookAuthorization.trim()
            : undefined,
      };
    } catch (error) {
      if (error instanceof RevenueCatVerificationError) throw error;
      throw configurationError('RevenueCat server secret is malformed.');
    }
  })();

  return cachedDefaultSecrets;
}

function parseList(value: unknown): RevenueCatList {
  if (
    typeof value !== 'object' ||
    value === null ||
    (value as Record<string, unknown>).object !== 'list' ||
    !Array.isArray((value as Record<string, unknown>).items)
  ) {
    throw retryableError('RevenueCat returned a malformed response.', 200);
  }

  const record = value as Record<string, unknown>;
  const items = record.items as unknown[];
  if (
    items.some(
      (item) =>
        typeof item !== 'object' ||
        item === null ||
        Array.isArray(item),
    )
  ) {
    throw retryableError('RevenueCat returned malformed list items.', 200);
  }

  const nextPage = record.next_page;
  if (
    nextPage !== undefined &&
    nextPage !== null &&
    typeof nextPage !== 'string'
  ) {
    throw retryableError('RevenueCat returned malformed pagination.', 200);
  }

  return {
    items: items as Record<string, unknown>[],
    nextPage: nextPage ?? null,
  };
}

function nextPageUrl(nextPage: string): string {
  try {
    const url = new URL(nextPage, revenueCatApiBaseUrl);
    if (url.origin !== revenueCatApiBaseUrl) {
      throw new Error('Unexpected origin');
    }
    return url.toString();
  } catch {
    throw retryableError('RevenueCat returned invalid pagination.', 200);
  }
}

async function fetchList(
  initialUrl: string,
  apiV2Key: string,
  fetchFn: typeof fetch,
  signal: AbortSignal,
): Promise<Record<string, unknown>[]> {
  const items: Record<string, unknown>[] = [];
  let url: string | null = initialUrl;

  for (let page = 0; page < maximumPageCount && url; page += 1) {
    try {
      const response = await fetchFn(url, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${apiV2Key}`,
          'Content-Type': 'application/json',
        },
        signal,
      });

      if (!response.ok) {
        const kind: RevenueCatFailureKind =
          response.status === 401 || response.status === 403
            ? 'configuration'
            : 'retryable';
        throw new RevenueCatVerificationError(
          kind,
          response.status,
          'RevenueCat verification request failed.',
        );
      }

      let payload: unknown;
      try {
        payload = await response.json();
      } catch {
        throw retryableError('RevenueCat returned invalid JSON.', 200);
      }

      const parsed = parseList(payload);
      items.push(...parsed.items);
      url = parsed.nextPage ? nextPageUrl(parsed.nextPage) : null;

      if (page === maximumPageCount - 1 && url) {
        throw retryableError(
          'RevenueCat pagination exceeded the safety limit.',
        );
      }
    } catch (error) {
      if (error instanceof RevenueCatVerificationError) throw error;
      throw retryableError('RevenueCat verification request failed.');
    }
  }

  return items;
}

function normalizedIds(
  items: Record<string, unknown>[],
  key: string,
): string[] {
  const ids = items.map((item) => item[key]);
  if (
    ids.some(
      (id) => typeof id !== 'string' || id.trim().length === 0,
    )
  ) {
    throw retryableError('RevenueCat returned malformed identifiers.', 200);
  }

  return [...new Set((ids as string[]).map((id) => id.trim()))];
}

export function createRevenueCatClient(
  deps: RevenueCatClientDeps = { config: configFromEnvironment() },
): RevenueCatClient {
  const fetchFn = deps.fetchFn ?? fetch;
  const loadSecrets =
    deps.loadSecrets ?? loadRevenueCatServerSecrets;
  const now = deps.now ?? (() : Date => new Date());

  return {
    async verifyCustomer(
      customerId: string,
    ): Promise<VerifiedRevenueCatCustomer> {
      validateConfig(deps.config);
      const normalizedCustomerId = customerId.trim();
      if (!normalizedCustomerId) {
        throw configurationError('RevenueCat customer id is required.');
      }

      const abortController = new AbortController();
      let timeout: ReturnType<typeof setTimeout> | undefined;
      const deadline = new Promise<never>((_resolve, reject) => {
        timeout = setTimeout(() => {
          abortController.abort();
          reject(retryableError('RevenueCat verification timed out.'));
        }, deps.config.timeoutMs);
      });

      const verification = (async (): Promise<VerifiedRevenueCatCustomer> => {
        let secrets: RevenueCatSecrets;
        try {
          secrets = await loadSecrets(deps.config.serverSecretArn);
        } catch (error) {
          if (error instanceof RevenueCatVerificationError) throw error;
          throw configurationError('RevenueCat server secret could not be loaded.');
        }
        if (!secrets.apiV2Key?.trim()) {
          throw configurationError('RevenueCat server secret is missing apiV2Key.');
        }

        const projectId = encodeURIComponent(deps.config.projectId);
        const encodedCustomerId = encodeURIComponent(normalizedCustomerId);
        const customerBase =
          `${revenueCatApiBaseUrl}/v2/projects/${projectId}/customers/${encodedCustomerId}`;
        const apiV2Key = secrets.apiV2Key.trim();

        const [entitlementItems, aliasItems] = await Promise.all([
          fetchList(
            `${customerBase}/active_entitlements?limit=100`,
            apiV2Key,
            fetchFn,
            abortController.signal,
          ),
          fetchList(
            `${customerBase}/aliases?limit=100`,
            apiV2Key,
            fetchFn,
            abortController.signal,
          ),
        ]);

        const activeEntitlementIds = normalizedIds(
          entitlementItems,
          'entitlement_id',
        );
        const aliases = normalizedIds(aliasItems, 'id');

        return {
          customerId: normalizedCustomerId,
          plan: activeEntitlementIds.includes(deps.config.proEntitlementId)
            ? 'PRO'
            : 'FREE',
          aliases,
          activeEntitlementIds,
          verifiedAt: now().toISOString(),
        };
      })();

      try {
        return await Promise.race([verification, deadline]);
      } finally {
        if (timeout) clearTimeout(timeout);
        abortController.abort();
      }
    },
  };
}

export async function verifyRevenueCatCustomer(
  customerId: string,
): Promise<VerifiedRevenueCatCustomer> {
  return createRevenueCatClient().verifyCustomer(customerId);
}
