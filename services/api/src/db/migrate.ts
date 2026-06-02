import { readFileSync, readdirSync } from 'fs';
import { join } from 'path';
import { getPool, closePool } from './client';

/**
 * Simple migration runner for PostgreSQL.
 *
 * - Reads SQL files from migrations/ directory
 * - Tracks applied migrations in schema_migrations table
 * - Runs each migration in a transaction (atomic per file)
 * - Can be invoked as a Lambda handler or programmatically
 */

import { migrations } from './migrations';

export async function runMigrations(): Promise<string[]> {
  const pool = await getPool();

  // Create migrations tracking table (idempotent)
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  // Get already-applied migrations
  const applied = await pool.query<{ version: string }>(
    'SELECT version FROM schema_migrations ORDER BY version',
  );
  const appliedSet = new Set(applied.rows.map((r) => r.version));

  // Get migration files sorted by name
  const files = Object.keys(migrations).sort();

  const results: string[] = [];

  for (const file of files) {
    if (appliedSet.has(file)) {
      results.push(`SKIP ${file} (already applied)`);
      continue;
    }

    const sql = migrations[file];

    // Run migration in a transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query(
        'INSERT INTO schema_migrations (version) VALUES ($1)',
        [file],
      );
      await client.query('COMMIT');
      results.push(`OK ${file}`);
      console.log(`Migration applied: ${file}`);
    } catch (error) {
      await client.query('ROLLBACK');
      const message = error instanceof Error ? error.message : String(error);
      console.error(`Migration ${file} failed:`, message);
      throw new Error(`Migration ${file} failed: ${message}`);
    } finally {
      client.release();
    }
  }

  return results;
}

/** Lambda handler — invoke to run pending migrations. */
export async function handler(event?: any): Promise<{
  statusCode: number;
  body: string;
}> {
  try {
    if (event && event.action === 'reseed') {
      console.log('Reseeding database with test data (migration 003)...');
      const pool = await getPool();
      const sql = migrations['003_seed_test_data'];
      await pool.query(sql);
      return {
        statusCode: 200,
        body: JSON.stringify({ status: 'ok', message: 'Test data reseeded successfully!' }),
      };
    }

    const results = await runMigrations();

    console.log('Migration results:', results);

    return {
      statusCode: 200,
      body: JSON.stringify({ status: 'ok', results }),
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Migration failed:', message);

    return {
      statusCode: 500,
      body: JSON.stringify({ status: 'error', error: message }),
    };
  } finally {
    await closePool();
  }
}
