-- ============================================================================
-- 020_add_candidate_checkin_counters
-- Add check-in counter fields to place_candidates for pending custom places.
-- ============================================================================

ALTER TABLE place_candidates
  ADD COLUMN IF NOT EXISTS checkin_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cover_media_id TEXT;
