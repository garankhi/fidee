# Fidee Database Architecture

## 1. Overview

Fidee sử dụng kiến trúc **Hybrid Database**: DynamoDB cho high-throughput writes và simple lookups (MVP), Aurora PostgreSQL cho geo-spatial queries, fuzzy text search, và AI vector embeddings (planned).

### Tại sao Hybrid?

| Requirement | DynamoDB | PostgreSQL |
|-------------|----------|------------|
| Simple key-value lookup (user profile, media by ID) | ✅ Tối ưu | Overkill |
| High-throughput event-driven writes (media upload) | ✅ Tối ưu | OK |
| Geo-spatial query (tìm trong bán kính 100m) | ⚠️ Geohash workaround | ✅ PostGIS native |
| Fuzzy text search ("cafe binh minh" ≈ "Cà Phê Bình Minh") | ❌ Không hỗ trợ | ✅ pg_trgm native |
| AI vector similarity search | ❌ Không hỗ trợ | ✅ pgvector native |
| Relational analytics (user → place → check-in) | ❌ Denormalize | ✅ JOIN native |
| Cost at MVP scale | ✅ $0 (PAY_PER_REQUEST) | ⚠️ ~$50/mo minimum |

### Decision Matrix

```
MVP (hiện tại):  DynamoDB only → $0/mo
Phase 3 (planned): DynamoDB + Aurora PostgreSQL → ~$50/mo
Phase 5 (planned): + Bedrock embeddings → ~$80/mo
```

---

## 2. DynamoDB Schema (MVP — Active)

### 2.1 Tables

Fidee sử dụng 2 DynamoDB tables, cả hai đều dùng `PAY_PER_REQUEST` billing:

| Table | CDK Resource | Physical Name | Partition Key | Sort Key |
|-------|-------------|---------------|---------------|----------|
| PlacesTable | `FideeStack/PlacesTable` | `fidee-{stage}-places` | `PK` (String) | `SK` (String) |
| UserProfilesTable | `FideeStack/UserProfilesTable` | `fidee-{stage}-user-profiles` | `userId` (String) | — |

### 2.2 PlacesTable — Entity Types

PlacesTable là multi-entity table chứa 2 entity types: **Media** và **PlaceCandidate**.

#### Entity: Media

Được tạo bởi `handle-media-uploaded` Lambda khi user upload ảnh qua S3.

| Attribute | Type | Example | Description |
|-----------|------|---------|-------------|
| `PK` | String | `MEDIA#med_01J0CAMERA001` | Partition key |
| `SK` | String | `METADATA` | Sort key (fixed) |
| `entityType` | String | `Media` | Entity discriminator |
| `mediaId` | String | `med_01J0CAMERA001` | Unique media identifier |
| `ownerUserId` | String | `cognito-sub-uuid` | Cognito user ID |
| `status` | String | `PENDING_MODERATION` | Review status |
| `s3Bucket` | String | `fidee-dev-media-xxx` | S3 bucket name |
| `s3Key` | String | `uploads/med_01J0CAMERA001.jpg` | S3 object key |
| `contentType` | String | `image/jpeg` | MIME type |
| `contentLength` | Number | `2048000` | File size in bytes |
| `source` | String | `IN_APP_CAMERA` | `IN_APP_CAMERA` \| `EXIF_GALLERY` |
| `gpsProof` | Map | `{lat, lng, accuracy, timestamp}` | GPS data at capture time |
| `createdAt` | String | `2026-05-30T12:00:00Z` | ISO 8601 |
| `updatedAt` | String | `2026-05-30T12:00:00Z` | ISO 8601 |
| `GSI1PK` | String | `USER#cognito-sub-uuid` | User's media index |
| `GSI1SK` | String | `MEDIA#2026-05-30T12:00:00Z#med_01J0CAMERA001` | Time-sorted |

#### Entity: PlaceCandidate

Được tạo bởi `create-place-candidate` Lambda khi user tạo địa điểm mới.

| Attribute | Type | Example | Description |
|-----------|------|---------|-------------|
| `PK` | String | `CANDIDATE#cand_abc123def456` | Partition key |
| `SK` | String | `META` | Sort key (fixed) |
| `entityType` | String | `PlaceCandidate` | Entity discriminator |
| `candidateId` | String | `cand_abc123def456` | Unique candidate ID |
| `name` | String | `Quán Cà Phê Bình Minh` | Original name (with diacritics) |
| `normalizedName` | String | `quan ca phe binh minh` | Lowercase, no diacritics, trimmed |
| `category` | String | `cafe` | One of 7 categories (see below) |
| `lat` | Number | `10.771597` | Latitude |
| `lng` | Number | `106.704416` | Longitude |
| `geohash` | String | `w3gv` | 4-char geohash (~20km cell) |
| `status` | String | `PENDING_REVIEW` | `PENDING_REVIEW` \| `APPROVED` \| `REJECTED` |
| `visibility` | String | `FRIENDS` | `FRIENDS` \| `PUBLIC` |
| `createdBy` | String | `cognito-sub-uuid` | Cognito user ID |
| `mediaId` | String | `med_01J0CAMERA001` | Associated photo |
| `createdAt` | String | `2026-05-30T12:00:00Z` | ISO 8601 |
| `updatedAt` | String | `2026-05-30T12:00:00Z` | ISO 8601 |
| `GSI1PK` | String | `USER_CANDIDATES#cognito-sub-uuid` | User's candidate quota |
| `GSI1SK` | String | `2026-05-30#cand_abc123def456` | Date-sorted for quota |
| `GSI2PK` | String | `GEO#w3gv` | Geohash cell for dedup |
| `GSI2SK` | String | `CANDIDATE#quan ca phe binh minh#cand_abc123` | Name-sorted within cell |

### 2.3 PlacesTable — Global Secondary Indexes

| Index | Partition Key | Sort Key | Purpose |
|-------|--------------|----------|---------|
| `GSI1` | `GSI1PK` | `GSI1SK` | Query user's media or today's candidates |
| `GSI2` | `GSI2PK` | `GSI2SK` | Geo-based duplicate detection |

#### GSI1 Access Patterns

```
# Get user's media (sorted by time)
GSI1PK = "USER#{userId}"
GSI1SK begins_with "MEDIA#"

# Count user's candidates today (quota check)
GSI1PK = "USER_CANDIDATES#{userId}"
GSI1SK begins_with "2026-05-30#"
```

#### GSI2 Access Patterns

```
# Find candidates in geohash cell (dedup)
GSI2PK = "GEO#{geohash4}"           # e.g. "GEO#w3gv"
GSI2SK begins_with "CANDIDATE#"

# Geohash neighbors cover ~60km² area
# Query 9 cells (center + 8 neighbors) for 100m radius check
```

### 2.4 UserProfilesTable

Simple key-value table, 1 entity type.

| Attribute | Type | Example | Description |
|-----------|------|---------|-------------|
| `userId` | String | `cognito-sub-uuid` | Cognito user ID (partition key) |
| `plan` | String | `FREE` | `FREE` \| `PRO` |
| `displayName` | String | `Minh` | User display name |
| `createdAt` | String | `2026-05-30T12:00:00Z` | ISO 8601 |
| `expiresAt` | Number | `1735689600` | TTL (epoch seconds) |

### 2.5 Place Categories

| Value | Vietnamese | Icon |
|-------|-----------|------|
| `cafe` | Cafe | ☕ |
| `restaurant` | Nhà hàng | 🍜 |
| `hotel` | Khách sạn | 🏨 |
| `tourist_attraction` | Du lịch | 📸 |
| `office` | Văn phòng | 🏢 |
| `shopping` | Mua sắm | 🛒 |
| `other` | Khác | 📍 |

---

## 3. PostgreSQL Schema (Implemented — CDK ready, pending deploy)

### 3.1 Design Philosophy: 3-Layer Separation

| Layer | Purpose | Tables | Update Frequency |
|-------|---------|--------|-----------------|
| **Core** | Immutable data + embeddings | `users`, `places` | Never (or very rarely) |
| **Settings** | Mutable metadata | `user_settings`, `place_settings` | Frequently |
| **Logs** | Audit trail | `place_moderation` | Append-only |

Why: `places` table contains VECTOR(1536) embeddings (~6KB per row). Separating mutable fields (visibility, status) into `place_settings` avoids rewriting large vector rows on every status change.

### 3.2 Infrastructure (CDK ready)

| Component | Spec | Cost |
|-----------|------|------|
| Engine | Aurora Serverless v2, PostgreSQL 16.4 | — |
| Min capacity | 0.5 ACU (dev) | ~$43/mo |
| Max capacity | 2 ACU (dev), 8 ACU (prod) | Variable |
| VPC | Private Isolated subnets, no NAT ($0) | $0 |
| VPC Endpoints | DynamoDB (gateway), S3 (gateway), Secrets Manager (interface) | ~$7/mo |
| Secrets Manager | DB credentials (auto-generated) | ~$0.40/mo |
| **Total (dev)** | | **~$50/mo** |

### 3.3 All 8 Tables

#### Group 1: Users

| Table | Type | Relationship | Purpose |
|-------|------|-------------|---------|
| `users` | Core | — | Profile, plan, counters |
| `user_settings` | Settings | 1:1 with users | Privacy, notifications, preferences |
| `friendships` | Graph | N:N (two-row model) | Social connections |

#### Group 2: Places

| Table | Type | Relationship | Purpose |
|-------|------|-------------|---------|
| `places` | Core + Embedding | — | Name, location, VECTOR(1536) |
| `place_settings` | Settings | 1:1 with places | visibility, status |
| `place_moderation` | Audit log | 1:N with places | Review history |
| `place_candidates` | Temporary | — | Pre-approval, deleted after promote |

#### Group 3: Activity

| Table | Type | Relationship | Purpose |
|-------|------|-------------|---------|
| `check_ins` | Activity | user → place → media | Check-in history |

### 3.4 Key Indexes

| Index | Table | Type | Purpose |
|-------|-------|------|---------|
| `idx_places_location` | places | GIST | Geo: `ST_DWithin()` |
| `idx_places_name_trgm` | places | GIN | Fuzzy: `similarity()` |
| `idx_psettings_visibility` | place_settings | B-Tree | Filter approved + public |
| `idx_friendships_status` | friendships | B-Tree | Get user's accepted friends |
| `idx_friendships_pending` | friendships | B-Tree (partial) | Pending friend requests |
| `idx_checkins_user` | check_ins | B-Tree | User history |
| `idx_checkins_place` | check_ins | B-Tree | Place activity |
| `idx_checkins_recent` | check_ins | B-Tree (partial) | Visible check-ins only |
| `idx_candidates_location` | place_candidates | GIST | Geo dedup |
| `idx_candidates_name_trgm` | place_candidates | GIN | Fuzzy name dedup |

### 3.5 Key Queries

#### Home Map: Friends' check-ins

```sql
SELECT ci.id, ci.caption, ci.created_at, ci.media_id,
       u.display_name, u.avatar_url,
       p.name AS place_name, p.category,
       ST_Y(p.location::geometry) AS lat,
       ST_X(p.location::geometry) AS lng
FROM check_ins ci
JOIN users u ON u.id = ci.user_id
JOIN places p ON p.id = ci.place_id
WHERE ci.user_id IN (
    SELECT friend_id FROM friendships
    WHERE user_id = $my_id AND status = 'ACCEPTED'
    UNION ALL SELECT $my_id
  )
  AND ST_DWithin(p.location, ST_MakePoint($lng, $lat)::geography, $radius)
  AND ci.visibility IN ('PUBLIC', 'FRIENDS')
ORDER BY ci.created_at DESC
LIMIT 50;
```

#### AI Search (future)

```sql
SELECT p.id, p.name,
       1 - (p.embedding <=> $query_vector) AS score
FROM places p
JOIN place_settings ps ON p.id = ps.place_id
WHERE ps.status = 'APPROVED' AND ps.visibility = 'PUBLIC'
  AND ST_DWithin(p.location, ST_MakePoint($lng, $lat)::geography, $radius)
ORDER BY score DESC LIMIT 10;
```

### 3.6 Friendships — Two-row model

Each friendship = 2 rows: `(Minh→Hân)` + `(Hân→Minh)`.

Why: Simple queries (`WHERE user_id = $me`) without OR conditions, better index usage.

### 3.7 Extensions

| Extension | Purpose |
|-----------|---------|
| `postgis` | `GEOGRAPHY(Point, 4326)`, `ST_DWithin()`, GIST indexes |
| `pg_trgm` | `similarity()`, GIN trigram indexes |
| `vector` | `VECTOR(1536)`, `<=>` cosine distance, IVFFlat indexes |

---

## 4. Data Ownership Split

### Stays in DynamoDB (permanent)

| Data | Table | Reason |
|------|-------|--------|
| Media metadata | PlacesTable (`MEDIA#*`) | High-throughput S3 event-driven writes |
| User plan (for Lambda auth) | UserProfilesTable | Simple K-V lookup |

### Lives in PostgreSQL

| Data | Table | Reason |
|------|-------|--------|
| User profiles (social) | `users` + `user_settings` | Friend queries, JOINs |
| Friendships | `friendships` | Social graph |
| Places (approved) | `places` + `place_settings` | Geo search, AI embeddings |
| Place moderation | `place_moderation` | Audit log |
| Place candidates | `place_candidates` | Geo dedup with PostGIS |
| Check-ins | `check_ins` | Relational (user → place → media) |

### Sync Strategy

Cognito sign-up → Lambda trigger → INSERT both DynamoDB (plan) and PostgreSQL (users + user_settings).

---

## 5. Vietnamese Name Normalization

Place names phải normalize trước khi so sánh để xử lý diacritics tiếng Việt:

```
Input:  "Quán Cà Phê Bình Minh"
Step 1: Remove diacritics → "Quan Ca Phe Binh Minh"
Step 2: Lowercase → "quan ca phe binh minh"
Step 3: Collapse whitespace → "quan ca phe binh minh"
Output: "quan ca phe binh minh"
```

Diacritics map xử lý đầy đủ 89 ký tự tiếng Việt (xem `services/api/src/utils/geo.ts`).

---

## 6. Geohash Encoding (DynamoDB workaround)

DynamoDB không có native geo query. Fidee dùng geohash workaround:

| Precision | Cell Size | Use Case |
|-----------|-----------|----------|
| 4 chars | ~20km × 20km | Dedup query (query 9 cells + Haversine filter) |

```
Encode:  (10.7716, 106.7042) → "w3gv" (4 chars)
Neighbors: ["w3gv", "w3gu", "w3gy", "w3gt", ...] (9 cells)
```

Sau khi query GSI2 với 9 cells, dùng **Haversine distance** để filter chính xác <= 100m.

---

## 7. Full SQL Migration

File: `services/api/src/db/migrations/001_initial.sql`

Bao gồm:
- 8 tables: `users`, `user_settings`, `friendships`, `places`, `place_settings`, `place_moderation`, `place_candidates`, `check_ins`
- 3 extensions: `postgis`, `pg_trgm`, `vector`
- 14 indexes (GIST, GIN, B-Tree, partial indexes)
- 2 triggers (`updated_at` auto-update for settings tables)
- CHECK constraints cho status, visibility, category, plan
- Foreign key constraints with ON DELETE CASCADE

## 8. DB Utilities

| File | Purpose |
|------|---------|
| `services/api/src/db/client.ts` | PostgreSQL connection via Secrets Manager + pg Pool |
| `services/api/src/db/migrate.ts` | Migration runner (Lambda handler) |

## 9. CDK Resources

| Resource | Name | Purpose |
|----------|------|---------|
| VPC | `fidee-{stage}-vpc` | Private isolated subnets |
| Aurora Cluster | `fidee-{stage}-db` | PostgreSQL 16.4 Serverless v2 |
| Security Group | `fidee-{stage}-db-sg` | Aurora ingress (port 5432) |
| Security Group | `fidee-{stage}-lambda-sg` | Lambda egress to Aurora |
| Lambda | `fidee-{stage}-db-migrate` | Run SQL migrations |
| VPC Endpoint | DynamoDB Gateway | Lambda → DynamoDB from VPC |
| VPC Endpoint | S3 Gateway | Lambda → S3 from VPC |
| VPC Endpoint | Secrets Manager Interface | Lambda → Secrets Manager from VPC |

