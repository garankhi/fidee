ALTER TABLE user_subscriptions
  ADD COLUMN IF NOT EXISTS revenuecat_aliases TEXT[] NOT NULL DEFAULT '{}';

ALTER TABLE revenuecat_webhook_events
  ADD COLUMN IF NOT EXISTS candidate_app_user_ids TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS resolved_user_ids TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS processing_state TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS retention_expires_at TIMESTAMPTZ;

UPDATE revenuecat_webhook_events
SET candidate_app_user_ids = ARRAY[app_user_id]
WHERE candidate_app_user_ids = '{}'
  AND NULLIF(btrim(app_user_id), '') IS NOT NULL;

UPDATE revenuecat_webhook_events
SET processing_state = CASE
  WHEN processed_at IS NULL THEN 'pending'
  ELSE 'processed'
END
WHERE processing_state IS NULL OR processing_state = 'pending';

ALTER TABLE revenuecat_webhook_events
  DROP CONSTRAINT IF EXISTS revenuecat_webhook_events_processing_state_check;

ALTER TABLE revenuecat_webhook_events
  ADD CONSTRAINT revenuecat_webhook_events_processing_state_check
  CHECK (processing_state IN ('pending_identity', 'pending', 'processed'));

UPDATE revenuecat_webhook_events
SET retention_expires_at = received_at + INTERVAL '30 days'
WHERE retention_expires_at IS NULL;

ALTER TABLE revenuecat_webhook_events
  ALTER COLUMN retention_expires_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_revenuecat_webhook_candidates
  ON revenuecat_webhook_events USING GIN (candidate_app_user_ids);

CREATE INDEX IF NOT EXISTS idx_revenuecat_webhook_pending_identity
  ON revenuecat_webhook_events (processing_state, retention_expires_at)
  WHERE processing_state = 'pending_identity';
