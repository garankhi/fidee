-- ============================================================================
-- 017_review_media
-- Add media_ids column to reviews table for photo attachments (max 5).
-- ============================================================================

ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS media_ids TEXT[] DEFAULT '{}';
