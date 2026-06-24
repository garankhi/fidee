-- ============================================================================
-- 019_add_checkin_count_to_places
-- Add checkin_count column to places to denormalize check-in counts
-- ============================================================================

ALTER TABLE places
  ADD COLUMN IF NOT EXISTS checkin_count INTEGER NOT NULL DEFAULT 0;
