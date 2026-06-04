-- ============================================================================
-- 009_candidate_missing_columns
-- Add missing columns to place_candidates that are expected by APIs
-- ============================================================================

ALTER TABLE place_candidates
  ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'FRIENDS',
  ADD COLUMN IF NOT EXISTS open_time TEXT,
  ADD COLUMN IF NOT EXISTS close_time TEXT,
  ADD COLUMN IF NOT EXISTS price_min INTEGER,
  ADD COLUMN IF NOT EXISTS price_max INTEGER,
  ADD COLUMN IF NOT EXISTS phone_number TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT;
