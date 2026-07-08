import { describe, expect, it } from 'vitest';
import { migrations } from './index';

describe('database migrations', () => {
  it('adds check-in counter columns used by candidate check-ins', () => {
    const candidateCounterMigration = Object.values(migrations).find(
      (sql) =>
        sql.includes('ALTER TABLE place_candidates') &&
        sql.includes('checkin_count'),
    );

    expect(candidateCounterMigration).toBeDefined();
    expect(candidateCounterMigration!).toContain(
      'ADD COLUMN IF NOT EXISTS checkin_count',
    );
    expect(candidateCounterMigration!).toContain(
      'ADD COLUMN IF NOT EXISTS cover_media_id',
    );
  });
});
