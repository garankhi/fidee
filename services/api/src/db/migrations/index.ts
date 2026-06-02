export const migrations: Record<string, string> = {
  '001_initial': `-- ============================================================================
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
RETURNS TRIGGER AS \$\$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER trg_user_settings_updated
  BEFORE UPDATE ON user_settings
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_place_settings_updated
  BEFORE UPDATE ON place_settings
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
`,
  '002_add_place_fields': `-- ============================================================================
-- 002_add_place_fields
-- Add rich fields for places based on UI requirements
-- ============================================================================

-- Add columns to places
ALTER TABLE places
  ADD COLUMN open_time TIME,
  ADD COLUMN close_time TIME,
  ADD COLUMN price_min INTEGER,
  ADD COLUMN price_max INTEGER,
  ADD COLUMN phone_number TEXT,
  ADD COLUMN description TEXT;

-- Add columns to place_candidates
ALTER TABLE place_candidates
  ADD COLUMN open_time TIME,
  ADD COLUMN close_time TIME,
  ADD COLUMN price_min INTEGER,
  ADD COLUMN price_max INTEGER,
  ADD COLUMN phone_number TEXT,
  ADD COLUMN description TEXT;
`,
  '003_seed_test_data': `-- ============================================================================
-- 003_seed_test_data
-- Seed test data for development: users, places, friendships, check_ins
-- All places are around District 1, Ho Chi Minh City
-- ============================================================================

-- ── Test Users ───────────────────────────────────────────────────────────────
INSERT INTO users (id, display_name, username, avatar_url, bio, plan, email)
VALUES
  ('test-user-001', 'Minh Trần', 'minhtran', NULL, 'Foodie Sài Gòn 🍜', 'FREE', 'minh@test.com'),
  ('test-user-002', 'Hân Nguyễn', 'hannguyen', NULL, 'Coffee addict ☕', 'FREE', 'han@test.com'),
  ('test-user-003', 'Khoa Lê', 'khoale', NULL, 'Photographer 📸', 'PRO', 'khoa@test.com')
ON CONFLICT (id) DO NOTHING;

-- ── User Settings ────────────────────────────────────────────────────────────
INSERT INTO user_settings (user_id)
VALUES ('test-user-001'), ('test-user-002'), ('test-user-003')
ON CONFLICT (user_id) DO NOTHING;

-- ── Friendships (bidirectional) ──────────────────────────────────────────────
-- Minh <-> Hân (accepted)
INSERT INTO friendships (user_id, friend_id, status, initiated_by, accepted_at)
VALUES
  ('test-user-001', 'test-user-002', 'ACCEPTED', 'test-user-001', NOW()),
  ('test-user-002', 'test-user-001', 'ACCEPTED', 'test-user-001', NOW()),
  ('test-user-001', 'test-user-003', 'ACCEPTED', 'test-user-003', NOW()),
  ('test-user-003', 'test-user-001', 'ACCEPTED', 'test-user-003', NOW())
ON CONFLICT (user_id, friend_id) DO NOTHING;

-- ── Places (around District 1, HCMC) ────────────────────────────────────────
-- Bitexco Tower area: 10.7716, 106.7042
-- Ben Thanh area: 10.7725, 106.6980
-- Nguyen Hue area: 10.7740, 106.7030

INSERT INTO places (id, name, normalized_name, category, address, location, source, created_by, open_time, close_time, price_min, price_max, phone_number, description, metadata)
VALUES
  (
    'a1000001-0001-0001-0001-000000000001',
    'The Coffee House - Nguyễn Huệ',
    'the coffee house nguyen hue',
    'cafe',
    '2 Nguyễn Huệ, Bến Nghé, Quận 1, TP.HCM',
    ST_MakePoint(106.7035, 10.7738)::geography,
    'custom',
    'test-user-001',
    '07:00', '22:30',
    35000, 75000,
    '028 7300 8888',
    'Không gian rộng, wifi mạnh, view Nguyễn Huệ',
    '{"vibes": ["Study", "Chill", "Group"], "services": ["Wifi", "Indoor", "Cashless", "Outlet"]}'::jsonb
  ),
  (
    'a1000001-0001-0001-0001-000000000002',
    'Phúc Long - Bitexco',
    'phuc long bitexco',
    'cafe',
    'Bitexco Financial Tower, 2 Hải Triều, Bến Nghé, Quận 1',
    ST_MakePoint(106.7045, 10.7718)::geography,
    'custom',
    'test-user-002',
    '07:30', '22:00',
    29000, 65000,
    NULL,
    'Trà sữa Phúc Long ngay tầng trệt Bitexco',
    '{"vibes": ["Chill", "Cafe"], "services": ["Wifi", "Indoor", "Cashless"]}'::jsonb
  ),
  (
    'a1000001-0001-0001-0001-000000000003',
    'Quán Bún Bò Huế Đông Ba',
    'quan bun bo hue dong ba',
    'restaurant',
    '110 Nguyễn Du, Bến Thành, Quận 1, TP.HCM',
    ST_MakePoint(106.6955, 10.7742)::geography,
    'custom',
    'test-user-001',
    '06:00', '21:00',
    40000, 65000,
    '0901 234 567',
    'Bún bò chuẩn vị Huế, nước dùng ninh xương 12 tiếng',
    '{"vibes": ["Group", "Healthy"], "services": ["Indoor", "Delivery"]}'::jsonb
  ),
  (
    'a1000001-0001-0001-0001-000000000004',
    'Katinat Saigon Kafe',
    'katinat saigon kafe',
    'cafe',
    '42 Đồng Khởi, Bến Nghé, Quận 1, TP.HCM',
    ST_MakePoint(106.7030, 10.7760)::geography,
    'custom',
    'test-user-003',
    '07:00', '23:00',
    45000, 89000,
    '028 3822 6868',
    'Premium cafe, signature Katinat sữa tươi trân châu',
    '{"vibes": ["Dating", "Chill", "Acoustic"], "services": ["Wifi", "Indoor", "Outdoor", "Cashless"]}'::jsonb
  ),
  (
    'a1000001-0001-0001-0001-000000000005',
    'Pizza 4P''s Ben Thanh',
    'pizza 4ps ben thanh',
    'restaurant',
    '8 Thủ Khoa Huân, Bến Thành, Quận 1, TP.HCM',
    ST_MakePoint(106.6978, 10.7728)::geography,
    'custom',
    'test-user-002',
    '10:00', '22:00',
    120000, 350000,
    '028 3622 0500',
    'Pizza Nhật kiểu Ý, cheese homemade tại chỗ',
    '{"vibes": ["Dating", "Group"], "services": ["Indoor", "Cashless", "No Pet"]}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

-- ── Place Settings (all APPROVED + PUBLIC) ───────────────────────────────────
INSERT INTO place_settings (place_id, visibility, status)
VALUES
  ('a1000001-0001-0001-0001-000000000001', 'PUBLIC', 'APPROVED'),
  ('a1000001-0001-0001-0001-000000000002', 'PUBLIC', 'APPROVED'),
  ('a1000001-0001-0001-0001-000000000003', 'PUBLIC', 'APPROVED'),
  ('a1000001-0001-0001-0001-000000000004', 'PUBLIC', 'APPROVED'),
  ('a1000001-0001-0001-0001-000000000005', 'PUBLIC', 'APPROVED')
ON CONFLICT (place_id) DO NOTHING;

-- ── Place Candidates (friends-only, not yet approved) ────────────────────────
-- Hân created a candidate near Nguyen Hue
INSERT INTO place_candidates (id, name, normalized_name, category, location, created_by, media_id, open_time, close_time, price_min, price_max, description)
VALUES
  (
    'b2000001-0001-0001-0001-000000000001',
    'Tiệm Cơm Nhà Làm',
    'tiem com nha lam',
    'restaurant',
    ST_MakePoint(106.7025, 10.7745)::geography,
    'test-user-002',
    'mock_media_candidate_001',
    '10:30', '20:00',
    30000, 50000,
    'Cơm nhà nấu mỗi ngày, rau sạch'
  ),
  (
    'b2000001-0001-0001-0001-000000000002',
    'Trà Đào Cam Sả Bà Năm',
    'tra dao cam sa ba nam',
    'cafe',
    ST_MakePoint(106.7040, 10.7722)::geography,
    'test-user-003',
    'mock_media_candidate_002',
    '08:00', '18:00',
    15000, 30000,
    'Trà đào pha tay cực ngon'
  )
ON CONFLICT (id) DO NOTHING;

-- ── Check-ins ────────────────────────────────────────────────────────────────
INSERT INTO check_ins (user_id, place_id, media_id, gps_lat, gps_lng, gps_accuracy, caption, rating, visibility)
VALUES
  ('test-user-001', 'a1000001-0001-0001-0001-000000000001', 'mock_media_ci_001', 10.7738, 106.7035, 5.2, 'Ngồi học bài cả chiều ở đây', 4, 'PUBLIC'),
  ('test-user-002', 'a1000001-0001-0001-0001-000000000002', 'mock_media_ci_002', 10.7718, 106.7045, 8.0, 'Trà sữa Phúc Long number one!', 5, 'FRIENDS'),
  ('test-user-003', 'a1000001-0001-0001-0001-000000000004', 'mock_media_ci_003', 10.7760, 106.7030, 3.1, 'Katinat chưa bao giờ làm thất vọng', 5, 'PUBLIC'),
  ('test-user-001', 'a1000001-0001-0001-0001-000000000005', 'mock_media_ci_004', 10.7728, 106.6978, 6.5, 'Pizza 4Ps luôn đỉnh', 4, 'PUBLIC')
ON CONFLICT DO NOTHING;
`,
  '004_update_moderation_schema': `-- ============================================================================
-- 004_update_moderation_schema
-- Relax place_id constraint and add candidate_id to support candidate rejection
-- ============================================================================

ALTER TABLE place_moderation
  ALTER COLUMN place_id DROP NOT NULL,
  ADD COLUMN candidate_id UUID;
`,
  '005_sync_candidate_fields': `-- ============================================================================
-- 005_sync_candidate_fields
-- Sync place_candidates schema with places so Approve is a clean copy.
-- Fields added: address, metadata (vibes, services, media arrays)
-- ============================================================================

ALTER TABLE place_candidates
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';
`,
  '006_candidate_status': `-- ============================================================================
-- 006_candidate_status
-- Add status + rejection_reason directly on place_candidates.
-- Status lifecycle: PENDING_REVIEW → APPROVED / REJECTED / NEEDS_MORE_INFO
-- ============================================================================

ALTER TABLE place_candidates
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'PENDING_REVIEW'
    CHECK (status IN ('PENDING_REVIEW', 'APPROVED', 'REJECTED', 'NEEDS_MORE_INFO')),
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_by TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
`,
  '007_candidate_checkin_ref': `-- ============================================================================
-- 007_candidate_checkin_ref
-- Cho phép user check-in vào quán chưa duyệt (đang là candidate)
-- ============================================================================

ALTER TABLE check_ins
  ALTER COLUMN place_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS candidate_id UUID;
`,
  '008_seed_test_user': `-- ============================================================================
-- 008_seed_test_user
-- Insert test user so check-in APIs don't fail foreign key checks
-- ============================================================================

INSERT INTO users (id, display_name, username, avatar_url, bio, plan, checkin_count, friend_count)
VALUES (
  '696a35fc-50e1-7069-67c5-70ace3fcf12e',
  'Test User',
  'testuser',
  'https://ui-avatars.com/api/?name=Test+User',
  'I am a test user',
  'FREE',
  0,
  0
) ON CONFLICT (id) DO NOTHING;
`
};