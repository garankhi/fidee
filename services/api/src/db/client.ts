import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { Pool, QueryResult } from 'pg';

/**
 * PostgreSQL connection utility for Lambda functions.
 *
 * - Fetches DB credentials from Secrets Manager (cached across invocations)
 * - Creates a connection pool (module-level, reused across invocations)
 * - SSL enabled (required for Aurora)
 * - Pool size: min 0, max 5 (Lambda-appropriate)
 */

interface DbCredentials {
  username: string;
  password: string;
  host: string;
  port: number;
  dbname: string;
}

const secretsClient = new SecretsManagerClient({});
let pool: Pool | null = null;
let cachedCredentials: DbCredentials | null = null;

async function getCredentials(): Promise<DbCredentials> {
  if (cachedCredentials) return cachedCredentials;

  const secretArn = process.env.DB_SECRET_ARN;
  if (!secretArn) throw new Error('DB_SECRET_ARN env var is required');

  const result = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: secretArn }),
  );

  if (!result.SecretString) throw new Error('DB secret is empty');

  cachedCredentials = JSON.parse(result.SecretString) as DbCredentials;
  return cachedCredentials;
}

/** Get or create the connection pool (cached across Lambda invocations). */
export async function getPool(): Promise<Pool> {
  if (pool) return pool;

  const creds = await getCredentials();

  pool = new Pool({
    host: process.env.DB_HOST || creds.host,
    port: parseInt(process.env.DB_PORT || String(creds.port), 10),
    database: process.env.DB_NAME || creds.dbname,
    user: creds.username,
    password: creds.password,
    ssl: { rejectUnauthorized: false },
    min: 0,
    max: 5,
    idleTimeoutMillis: 60_000,
    connectionTimeoutMillis: 5_000,
  });

  return pool;
}

/** Run a parameterized query. */
export async function query<T extends Record<string, unknown> = Record<string, unknown>>(
  sql: string,
  params?: unknown[],
): Promise<QueryResult<T>> {
  const p = await getPool();
  return p.query<T>(sql, params);
}

/** Close the pool (call at end of Lambda handler if needed). */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
