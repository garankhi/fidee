-- ============================================================================
-- 016_revenuecat_development_mode
-- Subscription state, RevenueCat webhook idempotency, and AI daily usage.
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_subscriptions (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  revenuecat_app_user_id TEXT NOT NULL UNIQUE,
  entitlement TEXT NOT NULL DEFAULT 'free' CHECK (entitlement IN ('free', 'pro')),
  plan TEXT NOT NULL DEFAULT 'FREE' CHECK (plan IN ('FREE', 'PRO')),
  store TEXT,
  product_id TEXT,
  period_type TEXT,
  expires_at TIMESTAMPTZ,
  last_event_at TIMESTAMPTZ,
  last_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  raw_customer_info JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS revenuecat_webhook_events (
  event_id TEXT PRIMARY KEY,
  app_user_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  product_id TEXT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  payload JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS ai_usage_daily (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
  input_count INTEGER NOT NULL DEFAULT 0 CHECK (input_count >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE check_ins
  ADD COLUMN IF NOT EXISTS media_type TEXT NOT NULL DEFAULT 'IMAGE'
  CHECK (media_type IN ('IMAGE', 'VIDEO'));

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_plan ON user_subscriptions(plan);
CREATE INDEX IF NOT EXISTS idx_ai_usage_daily_date ON ai_usage_daily(usage_date);
