import { describe, expect, it } from 'vitest';
import { migrations } from './index';

describe('database migrations', () => {
  it('adds check-in counter columns used by candidate check-ins', () => {
    const candidateCounterMigration = Object.values(migrations).find(
      (sql) => sql.includes('ALTER TABLE place_candidates') && sql.includes('checkin_count'),
    );

    expect(candidateCounterMigration).toBeDefined();
    expect(candidateCounterMigration!).toContain('ADD COLUMN IF NOT EXISTS checkin_count');
    expect(candidateCounterMigration!).toContain('ADD COLUMN IF NOT EXISTS cover_media_id');
  });

  it('adds and backfills separate profile name columns', () => {
    const migration = migrations['021_user_name_fields'];

    expect(migration).toBeDefined();
    expect(migration).toContain('ADD COLUMN IF NOT EXISTS family_name TEXT');
    expect(migration).toContain('ADD COLUMN IF NOT EXISTS given_name TEXT');
    expect(migration).toContain('regexp_replace');
    expect(migration).toContain('display_name');
    expect(migration).not.toContain('SET display_name =');
  });

  it('hardens RevenueCat reconciliation and webhook idempotency', () => {
    const migration = migrations['022_harden_revenuecat_reconciliation'];

    expect(migration).toBeDefined();
    expect(migration).toContain(
      "ADD COLUMN IF NOT EXISTS revenuecat_aliases TEXT[] NOT NULL DEFAULT '{}'",
    );
    expect(migration).toContain(
      "ADD COLUMN IF NOT EXISTS candidate_app_user_ids TEXT[] NOT NULL DEFAULT '{}'",
    );
    expect(migration).toContain(
      "ADD COLUMN IF NOT EXISTS resolved_user_ids TEXT[] NOT NULL DEFAULT '{}'",
    );
    expect(migration).not.toContain('resolved_user_id TEXT REFERENCES');
    expect(migration).toContain(
      "ADD COLUMN IF NOT EXISTS processing_state TEXT NOT NULL DEFAULT 'pending'",
    );
    expect(migration).toContain(
      'ADD COLUMN IF NOT EXISTS retention_expires_at TIMESTAMPTZ',
    );
    expect(migration).toContain(
      "CHECK (processing_state IN ('pending_identity', 'pending', 'processed'))",
    );
    expect(migration).toContain(
      'ON revenuecat_webhook_events USING GIN (candidate_app_user_ids)',
    );
  });
});
