# Fidee Technical Roadmap

## 1. Current State (2026-05-30)

### Deployed Infrastructure

| Component | Status | Notes |
|-----------|--------|-------|
| Cognito UserPool | ✅ Active | Email sign-in, OTP, 3 groups (Users/Moderators/Admins) |
| API Gateway + WAF | ✅ Active | 4 routes, Cognito JWT authorizer |
| S3 MediaBucket + CloudFront | ✅ Active | Image upload + CDN |
| DynamoDB PlacesTable | ✅ Active | 2 GSIs (GSI1, GSI2) |
| DynamoDB UserProfilesTable | ✅ Active | Simple K-V for plan |
| SQS + EventBridge | ✅ Active | Media upload pipeline |
| Lambda Functions (5) | ✅ Active | search, profile, media-upload, media-handler, place-candidate |

### API Endpoints

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `POST /search` | POST | None | Keyword search places |
| `GET /profile` | GET | Cognito | Get user profile |
| `POST /media/uploads` | POST | Cognito | Create presigned S3 upload |
| `POST /place-candidates` | POST | Cognito | Create custom place candidate |

### Mobile App

| Screen | Status | Notes |
|--------|--------|-------|
| Login/OTP | ✅ Done | Cognito auth flow |
| Home (Map) | ✅ Done | OSM + search bar + check-in CTA |
| Camera | ✅ Done | In-app capture + gallery (Pro only) |
| Nearby Places Sheet | ✅ Done | Place selection + custom fallback |
| Create Place Form | ✅ Done | 6 UI states, mock API |

### Codebase

| Area | Stack | Location |
|------|-------|----------|
| Mobile | Flutter 3.x, Dart | `apps/mobile/` |
| Backend | Node.js 20.x, TypeScript | `services/api/` |
| Infrastructure | CDK v2, TypeScript | `infra/cdk/` |
| Web (planned) | — | `apps/web/` (chưa có) |

---

## 2. Completed Tickets

### Phase 1: Core Infrastructure

| Ticket | Description | Status |
|--------|-------------|--------|
| MAP-003 | Auth: Cognito + OTP flow | ✅ Done |
| MAP-004 | CDK Infrastructure setup | ✅ Done |
| MAP-031 | Media Upload: S3 presigned + EventBridge pipeline | ✅ Done |

### Phase 2: Camera-First Flow

| Ticket | Description | Status |
|--------|-------------|--------|
| MAP-13B | Camera screen + GPS capture + gallery (Pro) | ✅ Done |
| MAP-15 | Backend: POST /place-candidates, dedup, quota | ✅ Done |
| MAP-41 | Mobile: Custom place form UI | ✅ Done |
| MAP-43 | QA: Test cases defined | 📋 Pending test |

---

## 3. Next Steps — Short Term (1-2 weeks)

### 3A. Deploy & Integration Test

**Priority: P0**

| Task | Description | Est. |
|------|-------------|------|
| CDK deploy | `npx cdk deploy --all` → verify all resources | 1h |
| Integration test | Curl POST /place-candidates with real JWT | 2h |
| Mobile → API wiring | Replace mock service with real API calls | 4h |
| Camera → Nearby → Create flow | End-to-end mobile flow testing | 4h |

### 3B. Check-in Post (MAP-XX — New)

**Priority: P0**

User chọn place → tạo check-in post → hiển thị trong feed bạn bè.

| Task | Description | Est. |
|------|-------------|------|
| Backend: `POST /check-ins` | Create check-in with place + media | 4h |
| Backend: `GET /feed` | Get friend's check-ins (time-sorted) | 4h |
| Mobile: Check-in preview screen | Photo + place info + caption + "Post" button | 6h |
| Mobile: Feed screen | Friends' check-ins list | 8h |

### 3C. Admin Review Queue (MAP-XX — New)

**Priority: P1**

Admin xem pending candidates → approve/reject/merge.

| Task | Description | Est. |
|------|-------------|------|
| Backend: `GET /admin/candidates` | List pending candidates (Moderator/Admin only) | 3h |
| Backend: `PATCH /admin/candidates/:id` | Approve/reject with note | 3h |
| Web: Admin panel | Simple table with approve/reject buttons | 8h |

---

## 4. Next Steps — Medium Term (1-2 months)

### 4A. Aurora PostgreSQL (Phase 3)

**Priority: P1**

Deploy PostgreSQL cho geo/text/AI search. Xem chi tiết: `docs/Fidee_Database_Architecture.md`.

| Task | Description | Cost Impact |
|------|-------------|-------------|
| Add VPC + Aurora Serverless v2 to CDK | Private isolated subnets, no NAT | +$50/mo |
| Create DB client (`services/api/src/db/client.ts`) | Secrets Manager + connection pool | — |
| Run SQL migration (`001_initial.sql`) | PostGIS + pg_trgm + pgvector | — |
| Dual-write Lambda | Write to both DynamoDB + PostgreSQL | — |
| Read-switch | Read places/candidates from PostgreSQL | — |

### 4B. Nearby Places API (MAP-XX)

**Priority: P1**

Replace mock nearby API with real geo queries.

| Approach | Current (DynamoDB) | Future (PostgreSQL) |
|----------|-------------------|---------------------|
| Query | Geohash GSI2 + Haversine filter | `ST_DWithin()` native |
| Accuracy | ~20km cells then filter | Exact meter-level |
| Performance | Multiple GSI queries | Single indexed query |
| Fuzzy name | Levenshtein in application | `similarity()` in DB |

### 4C. Friends System (MAP-XX)

**Priority: P1**

| Task | Description |
|------|-------------|
| `POST /friends/request` | Send friend request |
| `PATCH /friends/request/:id` | Accept/decline |
| `GET /friends` | List mutual friends |
| Friends feed filter | Only show check-ins from mutual friends |

---

## 5. Next Steps — Long Term (3-6 months)

### 5A. AI Search (Phase 5)

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Embedding | Bedrock Titan Embeddings v2 (1536 dims) | Encode place descriptions |
| Vector store | pgvector in Aurora PostgreSQL | Similarity search |
| Query flow | Bedrock embed query → pgvector search → rerank | Semantic search |
| Geo filter | PostGIS `ST_DWithin()` in same query | Location-aware AI |
| Text fallback | pg_trgm `similarity()` | Fuzzy keyword match |

### 5B. Web App

| Screen | Priority | Notes |
|--------|----------|-------|
| Search page | P0 | Simple keyword → later AI |
| Place detail | P0 | Info + friend check-ins |
| Landing page | P2 | Marketing |

### 5C. Monetization

| Feature | Free | Pro |
|---------|------|-----|
| Camera check-in | ✅ | ✅ |
| Gallery upload | ❌ | ✅ |
| Custom places/day | 5 | 15 |
| AI search questions/day | 3 | 20 |
| Shop boost | ❌ | Future |

---

## 6. Cost Projection

| Phase | Monthly Cost | Components |
|-------|-------------|------------|
| **MVP (current)** | **~$5-15** | Lambda, DynamoDB (PAY_PER_REQUEST), S3, API Gateway, CloudFront, Cognito |
| **Phase 3** | **~$60-80** | + Aurora Serverless v2 ($43), VPC endpoints ($7) |
| **Phase 5** | **~$80-120** | + Bedrock embeddings (usage-based) |
| **Production** | **~$200-500** | Higher ACU, RDS Proxy, more Lambda, CDN traffic |

---

## 7. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS Cloud (ap-southeast-1)                    │
│                                                                      │
│  ┌──────────┐   ┌──────────┐   ┌───────────────────────────────┐   │
│  │ CloudFront│   │API Gateway│   │          Cognito              │   │
│  │   (CDN)   │   │  + WAF   │   │   UserPool + JWT Authorizer   │   │
│  └─────┬─────┘   └─────┬────┘   └───────────────────────────────┘   │
│        │               │                                             │
│  ┌─────▼─────┐   ┌─────▼────────────────────────────────────┐      │
│  │ S3 Media  │   │              Lambda Functions             │      │
│  │  Bucket   │   │  ┌────────────┐  ┌──────────────────┐    │      │
│  │           │   │  │ search     │  │ create-place-     │    │      │
│  │ uploads/* │   │  │            │  │ candidate         │    │      │
│  │           │   │  ├────────────┤  ├──────────────────┤    │      │
│  └─────┬─────┘   │  │ get-       │  │ create-media-    │    │      │
│        │         │  │ profile    │  │ upload           │    │      │
│        │         │  ├────────────┤  ├──────────────────┤    │      │
│  ┌─────▼─────┐   │  │ handle-    │  │                  │    │      │
│  │EventBridge│   │  │ media-     │  │                  │    │      │
│  │           │   │  │ uploaded   │  │                  │    │      │
│  └─────┬─────┘   │  └────────────┘  └──────────────────┘    │      │
│        │         └───────────────────────────┬───────────────┘      │
│  ┌─────▼─────┐                               │                      │
│  │  SQS      │                    ┌──────────▼──────────┐           │
│  │  Queue    │                    │     DynamoDB         │           │
│  │  + DLQ    │                    │  ┌───────────────┐   │           │
│  └───────────┘                    │  │ PlacesTable   │   │           │
│                                   │  │ (GSI1, GSI2)  │   │           │
│                                   │  ├───────────────┤   │           │
│                                   │  │ UserProfiles  │   │           │
│                                   │  │ Table         │   │           │
│                                   │  └───────────────┘   │           │
│                                   └──────────────────────┘           │
│                                                                      │
│  ┌──────────────────────────────────────────────────────┐ Phase 3   │
│  │                    VPC (planned)                       │           │
│  │  ┌──────────────────────────────────────────────┐    │           │
│  │  │  Aurora Serverless v2 (PostgreSQL 16)         │    │           │
│  │  │  ┌─────────┐  ┌────────┐  ┌────────────┐    │    │           │
│  │  │  │ PostGIS  │  │pg_trgm │  │ pgvector   │    │    │           │
│  │  │  │ geo      │  │ fuzzy  │  │ AI embed   │    │    │           │
│  │  │  └─────────┘  └────────┘  └────────────┘    │    │           │
│  │  └──────────────────────────────────────────────┘    │           │
│  └──────────────────────────────────────────────────────┘           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. File Structure

```
d:\mapvibe\
├── apps/
│   └── mobile/                          # Flutter app
│       └── lib/
│           ├── features/auth/           # Login, OTP, auth providers
│           ├── models/                  # Data models
│           ├── screens/
│           │   ├── camera_screen.dart
│           │   ├── create_place_screen.dart   ← NEW
│           │   ├── home_screen.dart           ← MODIFIED
│           │   ├── nearby_places_sheet.dart
│           │   └── otp_screen.dart
│           └── services/
│               ├── auth_service.dart
│               ├── location_service.dart
│               ├── nearby_service.dart
│               └── place_candidate_service.dart  ← NEW
│
├── services/
│   └── api/                             # Node.js Lambda backend
│       └── src/
│           ├── db/
│           │   └── migrations/
│           │       └── 001_initial.sql         ← NEW (PostgreSQL)
│           ├── handlers/
│           │   ├── create-media-upload.ts
│           │   ├── create-place-candidate.ts   ← NEW
│           │   ├── get-profile.ts
│           │   ├── handle-media-uploaded.ts
│           │   └── search.ts
│           ├── media/
│           │   └── validation.ts
│           ├── middleware/
│           │   └── auth.ts
│           ├── repositories/
│           │   ├── media-records.ts
│           │   ├── place-candidates.ts         ← NEW
│           │   └── user-profiles.ts
│           └── utils/
│               ├── geo.ts                      ← NEW
│               └── geo.test.ts                 ← NEW
│
├── infra/
│   └── cdk/
│       ├── bin/fidee-app.ts
│       └── lib/fidee-stack.ts                  ← MODIFIED
│
└── docs/
    ├── Fidee_Backlog.md
    ├── Fidee_Business_Rules.md
    ├── Fidee_Database_Architecture.md          ← NEW
    ├── Fidee_PRD.md
    ├── Fidee_Technical_Roadmap.md              ← NEW
    ├── MAP15_Implementation_Report.md          ← NEW
    └── System_Architechture.png
```
