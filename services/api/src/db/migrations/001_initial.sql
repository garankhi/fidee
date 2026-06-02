-- ============================================================================
-- Fidee PostgreSQL Schema — Full Migration
-- ============================================================================
--
-- Design Philosophy: 3-Layer Separation
--
--   Layer 1: Core tables (immutable or rarely changed)
--            → places, users
--            → Contains embedding vectors, geo data
--            → Optimized for READ (GIST, GIN, IVFFlat indexes)
--
--   Layer 2: Settings tables (mutable, frequently updated)
--            → place_settings, user_settings
--            → Small rows (~100 bytes), fast UPDATE
--            → Separated to avoid rewriting large vector rows
--
--   Layer 3: Log tables (append-only, audit trail)
--            → place_moderation
--            → Never UPDATE, only INSERT
--
-- Tables: 8 total
--   Users:    users, user_settings, friendships
--   Places:   places, place_settings, place_moderation, place_candidates
--   Activity: check_ins
--
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS postgis;       -- Geo: ST_DWithin, GEOGRAPHY
CREATE EXTENSION IF NOT EXISTS pg_trgm;       -- Fuzzy: similarity()
CREATE EXTENSION IF NOT EXISTS vector;        -- AI: pgvector embeddings


-- ════════════════════════════════════════════════════════════════════════════
-- GROUP 1: USERS
-- ════════════════════════════════════════════════════════════════════════════

-- ── users: Core user info (rarely changes) ──────────────────────────────────
CREATE TABLE users (
  id TEXT PRIMARY KEY,                          -- Cognito sub UUID
  display_name TEXT NOT NULL,
  username TEXT UNIQUE,                         -- @handle, set later
  avatar_url TEXT,                              -- S3/CloudFront URL
  bio TEXT CHECK (length(bio) <= 150),          -- "Foodie Sài Gòn 🍜"
  plan TEXT NOT NULL DEFAULT 'FREE'
    CHECK (plan IN ('FREE', 'PRO')),
  email TEXT,
  phone TEXT,
  auth_provider TEXT DEFAULT 'cognito',

  -- Denormalized counters (updated via trigger or batch job)
  friend_count INTEGER NOT NULL DEFAULT 0,
  checkin_count INTEGER NOT NULL DEFAULT 0,
  place_count INTEGER NOT NULL DEFAULT 0,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── user_settings: Mutable preferences (1:1 with users) ────────────────────
CREATE TABLE user_settings (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,

  -- Privacy
  profile_visibility TEXT NOT NULL DEFAULT 'PUBLIC'
    CHECK (profile_visibility IN ('PUBLIC', 'FRIENDS', 'PRIVATE')),
  show_on_map BOOLEAN NOT NULL DEFAULT TRUE,
  show_checkin_history BOOLEAN NOT NULL DEFAULT TRUE,

  -- Notifications
  notify_friend_checkin BOOLEAN NOT NULL DEFAULT TRUE,
  notify_friend_request BOOLEAN NOT NULL DEFAULT TRUE,
  notify_place_approved BOOLEAN NOT NULL DEFAULT TRUE,

  -- Preferences
  default_map_radius INTEGER NOT NULL DEFAULT 500,
  language TEXT NOT NULL DEFAULT 'vi',

  -- UI state ("Không hiện lại" checkboxes)
  hide_gallery_notice BOOLEAN NOT NULL DEFAULT FALSE,
  hide_gps_notice BOOLEAN NOT NULL DEFAULT FALSE,

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── friendships: Two-row bidirectional model ────────────────────────────────
-- Each friendship = 2 rows: (Minh→Hân) + (Hân→Minh)
-- Reason: Simple queries without OR conditions, better index usage
CREATE TABLE friendships (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'ACCEPTED', 'BLOCKED')),

  initiated_by TEXT,                -- userId of who sent the request
  nickname TEXT,                    -- Per-friend custom name
  is_muted BOOLEAN NOT NULL DEFAULT FALSE,
  is_close_friend BOOLEAN NOT NULL DEFAULT FALSE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,

  PRIMARY KEY (user_id, friend_id),
  CHECK (user_id != friend_id)      -- Cannot friend yourself
);


-- ════════════════════════════════════════════════════════════════════════════
-- GROUP 2: PLACES
-- ════════════════════════════════════════════════════════════════════════════

-- ── places: Core + embedding (IMMUTABLE after creation) ─────────────────────
-- This table is optimized for READ. It should rarely be UPDATEd.
-- visibility/status are in place_settings to avoid rewriting vector rows.
CREATE TABLE places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goong_place_id TEXT,                          -- External reference (nullable)
  source TEXT NOT NULL DEFAULT 'custom'
    CHECK (source IN ('goong_places', 'custom')),

  -- Core data (does NOT change)
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,                -- Lowercase, no diacritics
  category TEXT NOT NULL DEFAULT 'other'
    CHECK (category IN (
      'cafe', 'restaurant', 'hotel', 'tourist_attraction',
      'office', 'shopping', 'other'
    )),
  address TEXT,
  location GEOGRAPHY(Point, 4326) NOT NULL,     -- PostGIS geography

  -- Ownership
  created_by TEXT NOT NULL REFERENCES users(id),

  -- AI embedding (generated by Bedrock Titan v2, 1536 dimensions)
  -- NULL until embedding is generated
  embedding VECTOR(1536),

  -- Extra metadata
  metadata JSONB DEFAULT '{}',

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- NO updated_at: this table is immutable
);

-- ── place_settings: Mutable metadata (1:1 with places) ─────────────────────
-- Frequently updated fields separated from the large places table.
-- UPDATE here does NOT touch the embedding vector.
CREATE TABLE place_settings (
  place_id UUID PRIMARY KEY REFERENCES places(id) ON DELETE CASCADE,

  visibility TEXT NOT NULL DEFAULT 'FRIENDS'
    CHECK (visibility IN ('PUBLIC', 'FRIENDS', 'PRIVATE')),
  status TEXT NOT NULL DEFAULT 'PENDING_REVIEW'
    CHECK (status IN ('PENDING_REVIEW', 'APPROVED', 'HIDDEN', 'DELETED')),

  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by TEXT                                -- userId or 'SYSTEM'
);

-- ── place_moderation: Audit log (APPEND-ONLY) ──────────────────────────────
-- Records every status change, approval, rejection, merge, report.
-- Never UPDATE — only INSERT.
CREATE TABLE place_moderation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,

  action TEXT NOT NULL CHECK (action IN (
    'SUBMITTED',
    'AUTO_APPROVED',
    'APPROVED',
    'REJECTED',
    'HIDDEN',
    'REPORTED',
    'MERGED',
    'VISIBILITY_CHANGED'
  )),

  note TEXT,
  merged_into_place_id UUID REFERENCES places(id),
  previous_status TEXT,
  new_status TEXT,

  performed_by TEXT NOT NULL,                    -- userId or 'SYSTEM'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- NO updated_at: append-only table
);

-- ── place_candidates: Temporary pre-approval (deleted after promote) ────────
-- When admin approves: INSERT into places + place_settings, DELETE from here.
CREATE TABLE place_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(name) >= 2 AND length(name) <= 100),
  normalized_name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'other'
    CHECK (category IN (
      'cafe', 'restaurant', 'hotel', 'tourist_attraction',
      'office', 'shopping', 'other'
    )),
  location GEOGRAPHY(Point, 4326) NOT NULL,
  created_by TEXT NOT NULL REFERENCES users(id),
  media_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ════════════════════════════════════════════════════════════════════════════
-- GROUP 3: ACTIVITY
-- ════════════════════════════════════════════════════════════════════════════

-- ── check_ins: User check-in history ────────────────────────────────────────
CREATE TABLE check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id),
  place_id UUID NOT NULL REFERENCES places(id),
  media_id TEXT NOT NULL,                        -- Reference to DynamoDB media

  -- GPS proof at check-in time
  gps_lat DOUBLE PRECISION NOT NULL,
  gps_lng DOUBLE PRECISION NOT NULL,
  gps_accuracy DOUBLE PRECISION,

  -- Content
  caption TEXT,
  rating SMALLINT CHECK (rating >= 1 AND rating <= 5),

  -- Visibility (can differ from place visibility)
  visibility TEXT NOT NULL DEFAULT 'FRIENDS'
    CHECK (visibility IN ('PUBLIC', 'FRIENDS', 'PRIVATE')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ════════════════════════════════════════════════════════════════════════════
-- INDEXES
-- ════════════════════════════════════════════════════════════════════════════

-- ── Users ────────────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX idx_users_username ON users (username)
  WHERE username IS NOT NULL;
CREATE INDEX idx_users_email ON users (email)
  WHERE email IS NOT NULL;

-- ── Friendships ─────────────────────────────────────────────────────────────
CREATE INDEX idx_friendships_status ON friendships (user_id, status);
CREATE INDEX idx_friendships_pending ON friendships (friend_id, status)
  WHERE status = 'PENDING';                     -- Partial: only pending requests

-- ── Places ──────────────────────────────────────────────────────────────────
CREATE INDEX idx_places_location ON places USING GIST (location);
CREATE INDEX idx_places_name_trgm ON places USING GIN (normalized_name gin_trgm_ops);
CREATE INDEX idx_places_source ON places (source);

-- ── Place Settings ──────────────────────────────────────────────────────────
CREATE INDEX idx_psettings_status ON place_settings (status);
CREATE INDEX idx_psettings_visibility ON place_settings (visibility, status);

-- ── Place Moderation ────────────────────────────────────────────────────────
CREATE INDEX idx_moderation_place ON place_moderation (place_id, created_at DESC);
CREATE INDEX idx_moderation_performer ON place_moderation (performed_by, created_at DESC);

-- ── Place Candidates ────────────────────────────────────────────────────────
CREATE INDEX idx_candidates_location ON place_candidates USING GIST (location);
CREATE INDEX idx_candidates_name_trgm ON place_candidates
  USING GIN (normalized_name gin_trgm_ops);
CREATE INDEX idx_candidates_user_date ON place_candidates (created_by, created_at);

-- ── Check-ins ───────────────────────────────────────────────────────────────
CREATE INDEX idx_checkins_user ON check_ins (user_id, created_at DESC);
CREATE INDEX idx_checkins_place ON check_ins (place_id, created_at DESC);
CREATE INDEX idx_checkins_recent ON check_ins (created_at DESC)
  WHERE visibility IN ('PUBLIC', 'FRIENDS');    -- Partial: only visible ones

-- NOTE: IVFFlat index for embeddings should be created AFTER data is loaded:
-- CREATE INDEX idx_places_embedding ON places
--   USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);


-- ════════════════════════════════════════════════════════════════════════════
-- TRIGGERS
-- ════════════════════════════════════════════════════════════════════════════

-- Auto-update updated_at on settings tables
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_user_settings_updated
  BEFORE UPDATE ON user_settings
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_place_settings_updated
  BEFORE UPDATE ON place_settings
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
