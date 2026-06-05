# MAP-15 / MAP-41 / MAP-43: Custom Place Candidates — Implementation Report

## 1. Ticket Summary

| Ticket | Owner | Area | Status |
|--------|-------|------|--------|
| MAP-15 | ty ty | Backend: POST /place-candidates, dedup, quota, GPS proof | ✅ Implemented |
| MAP-41 | Nguyễn Thế Minh | Mobile: Custom place form UI | ✅ Implemented |
| MAP-43 | Duy | QA: Duplicate, near-duplicate, missing data, quota | 📋 Test cases defined |

### Context

Khi user chụp ảnh (camera-first flow) và không tìm thấy địa điểm phù hợp trong nearby results, user tap "Tạo địa điểm mới tại đây" → mobile mở form → POST request → backend xử lý.

---

## 2. Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│   Mobile App    │     │   API Gateway    │     │    Lambda           │
│                 │     │   + Cognito JWT   │     │                     │
│ CameraScreen    │     │                  │     │ create-place-       │
│       ↓         │────▶│ POST             │────▶│ candidate.handler   │
│ NearbySheet     │     │ /place-candidates│     │                     │
│       ↓         │     │                  │     │ ┌─────────────────┐ │
│ CreatePlaceForm │     └──────────────────┘     │ │ 1. Auth         │ │
│                 │                              │ │ 2. Validate     │ │
│ States:         │     ┌──────────────────┐     │ │ 3. S3 GPS check │ │
│ • Input form    │     │   DynamoDB       │     │ │ 4. Quota (GSI1) │ │
│ • Loading       │◀────│   PlacesTable    │◀────│ │ 5. Dedup (GSI2) │ │
│ • Success       │     │                  │     │ │ 6. Create       │ │
│ • Conflict      │     │ UserProfilesTable│     │ └─────────────────┘ │
│ • Quota limit   │     └──────────────────┘     │                     │
│ • Error         │                              │ ┌─────────────────┐ │
│                 │     ┌──────────────────┐     │ │ S3 MediaBucket  │ │
│                 │     │                  │◀────│ │ HeadObject      │ │
│                 │     │   S3 Bucket      │     │ │ (verify GPS)    │ │
└─────────────────┘     └──────────────────┘     │ └─────────────────┘ │
                                                 └─────────────────────┘
```

---

## 3. Backend Implementation

### 3.1 New Files

| File | Path | Lines | Purpose |
|------|------|-------|---------|
| `geo.ts` | `services/api/src/utils/geo.ts` | 158 | Haversine distance, geohash encode/decode/neighbors, Vietnamese diacritics removal, name normalization, Levenshtein distance |
| `geo.test.ts` | `services/api/src/utils/geo.test.ts` | 103 | 18 unit tests: haversine, geohash, normalize, levenshtein |
| `place-candidates.ts` | `services/api/src/repositories/place-candidates.ts` | 155 | DynamoDB CRUD: put, countToday (GSI1), findNearby (GSI2) |
| `create-place-candidate.ts` | `services/api/src/handlers/create-place-candidate.ts` | 195 | Lambda handler with DI pattern |
| `create-place-candidate.test.ts` | `services/api/src/handlers/create-place-candidate.test.ts` | 137 | 9 handler tests |

### 3.2 Handler Flow

```
POST /place-candidates
Authorization: Bearer {Cognito JWT}

1. extractAuth(event)
   → userId from Cognito JWT claims
   → Throw 401 if missing

2. validateCandidateRequest(body)
   → name (2-100 chars), category, mediaId, coordinates
   → Throw 400 if invalid

3. verifyMediaInS3(bucket, mediaId)
   → HeadObject on uploads/{mediaId}.{jpg|png|webp}
   → Read x-amz-meta-gps-latitude, x-amz-meta-gps-longitude
   → Return 400 INVALID_MEDIA if not found

4. getUserPlan(userId)
   → Query UserProfilesTable
   → Return FREE | PRO (missing = FREE)

5. countUserCandidatesToday(table, userId, today)
   → Query GSI1: USER_CANDIDATES#{userId}, begins_with({today}#)
   → Return 429 QUOTA_EXCEEDED if >= limit (FREE: 5, PRO: 15)

6. normalizeName(name)
   → Remove Vietnamese diacritics
   → Lowercase, collapse whitespace

7. encodeGeohash(lat, lng, 4)
   → 4-char geohash (~20km cell)

8. findNearbyCandidates(neighbors, 100m, normalizedName)
   → Query GSI2 for 9 geohash cells
   → Filter: Haversine <= 100m AND (exact match OR Levenshtein <= 3)
   → Return 409 NEAR_DUPLICATE if found (unless force=true)

9. putCandidate(table, candidate)
   → ConditionExpression: attribute_not_exists(PK)
   → Return 201 created
```

### 3.3 DI Pattern

Handler follows existing Fidee DI pattern (same as `create-media-upload`):

```typescript
// Dependencies injected for testability
interface CreatePlaceCandidateDeps {
  getPlan: (userId: string) => Promise<UserPlan>;
  putCandidate: (...) => Promise<'created' | 'duplicate'>;
  countToday: (...) => Promise<number>;
  findNearby: (...) => Promise<NearbyCandidate[]>;
  verifyMedia: (...) => Promise<{lat, lng} | null>;
  candidateIdFactory: () => string;
  env: { placesTable, mediaBucket, userProfilesTable };
}

// Tests mock all dependencies
const deps = {
  getPlan: vi.fn().mockResolvedValue('FREE'),
  putCandidate: vi.fn().mockResolvedValue('created'),
  // ...
};
const handler = createPlaceCandidateHandler(deps);
const result = await handler(mockEvent(body));
```

### 3.4 Dedup Algorithm

```
Input: name="Quán Cà Phê Bình Minh", lat=10.7716, lng=106.7042

Step 1: Normalize → "quan ca phe binh minh"
Step 2: Geohash → "w3gv"
Step 3: Neighbors → ["w3gv", "w3gu", "w3gy", "w3gt", ...] (9 cells)
Step 4: Query GSI2 for each cell
Step 5: For each result:
  - Haversine distance < 100m? → continue
  - Exact name match? → DUPLICATE
  - Levenshtein distance ≤ 3? → NEAR_DUPLICATE
Step 6: If duplicates found AND !force → 409
Step 7: Otherwise → create
```

### 3.5 Quota Rules

| Plan | Daily Limit | Enforcement |
|------|-------------|-------------|
| FREE | 5 candidates/day | GSI1 count query |
| PRO | 15 candidates/day | GSI1 count query |

---

## 4. CDK Infrastructure Changes

### File: `infra/cdk/lib/fidee-stack.ts`

| Change | Description |
|--------|-------------|
| +GSI2 | `PlacesTable.addGlobalSecondaryIndex('GSI2')` for geo-dedup |
| +Lambda | `create-place-candidate` function (256MB, 15s timeout) |
| +IAM | PlacesTable R/W, UserProfilesTable R, MediaBucket R (uploads/*) |
| +API Route | `POST /place-candidates` with Cognito authorizer |

### API Routes After Deploy

| Route | Method | Auth | Lambda |
|-------|--------|------|--------|
| `/search` | POST | None | `fidee-{stage}-search` |
| `/profile` | GET | Cognito | `fidee-{stage}-get-profile` |
| `/media/uploads` | POST | Cognito | `fidee-{stage}-create-media-upload` |
| **`/place-candidates`** | **POST** | **Cognito** | **`fidee-{stage}-create-place-candidate`** |

---

## 5. Mobile Implementation

### 5.1 New Files

| File | Path | Purpose |
|------|------|---------|
| `create_place_screen.dart` | `apps/mobile/lib/screens/` | Full-screen form with 6 UI states |
| `place_candidate_service.dart` | `apps/mobile/lib/services/` | Mock service (sẽ gọi API khi BE deployed) |

### 5.2 Modified Files

| File | Change |
|------|--------|
| `home_screen.dart` | `_onCheckIn()` → navigate to CameraScreen |

### 5.3 UI States

| State | Trigger | UI |
|-------|---------|-----|
| **Input** | Initial | Photo card + name field + category grid + submit button |
| **Loading** | After submit | Spinner + "Đang tạo địa điểm..." |
| **Success** | 201 response | ✅ icon + "PENDING REVIEW" badge + "Quay lại bản đồ" |
| **Conflict** | 409 response | ⚠️ banner + duplicate list + "Dùng" / "Vẫn tạo mới" |
| **Quota** | 429 response | 🚫 icon + quota counter + "Nâng cấp Pro" |
| **Error** | Network/server error | ❌ icon + error message + "Thử lại" |

### 5.4 Category Picker

7 categories with animated selection:

| Category | Icon | Color |
|----------|------|-------|
| Cafe | ☕ | Amber |
| Nhà hàng | 🍜 | Red |
| Khách sạn | 🏨 | Blue |
| Du lịch | 📸 | Purple |
| Văn phòng | 🏢 | Gray |
| Mua sắm | 🛒 | Pink |
| Khác | 📍 | Green |

---

## 6. API Contract

Full contract: `services/api/docs/contracts/place-candidates-contract.md`

### Request

```http
POST /place-candidates
Authorization: Bearer {Cognito JWT}
Content-Type: application/json

{
  "name": "Quán Cà Phê Bình Minh",
  "category": "cafe",
  "mediaId": "photo-uuid-abc-123",
  "coordinates": { "lat": 10.771597, "lng": 106.704416 },
  "force": false
}
```

### Response Codes

| Code | Status | Body | When |
|------|--------|------|------|
| 201 | `created` | `{ data: { candidate_id, name, status, ... } }` | Tạo thành công |
| 409 | `conflict` | `{ candidates: [...], error: { code: "NEAR_DUPLICATE" } }` | Trùng trong 100m |
| 429 | `error` | `{ error: { code: "QUOTA_EXCEEDED", daily_limit, used } }` | Vượt quota |
| 400 | `error` | `{ error: { code: "VALIDATION_ERROR", message } }` | Thiếu/sai field |
| 400 | `error` | `{ error: { code: "INVALID_MEDIA", message } }` | Media không có GPS |
| 401 | `error` | `{ error: { code: "UNAUTHORIZED" } }` | Thiếu JWT |

---

## 7. Test Results

```
59/59 tests passed ✅ (7 suites)

src/utils/geo.test.ts                         18 tests ✅
src/handlers/create-place-candidate.test.ts    9 tests ✅
src/handlers/create-media-upload.test.ts       9 tests ✅
src/handlers/handle-media-uploaded.test.ts     7 tests ✅
src/handlers/get-profile.test.ts               3 tests ✅
src/handlers/search.test.ts                    2 tests ✅
src/middleware/auth.test.ts                   11 tests ✅
```

---

## 8. QA Test Cases (MAP-43)

| # | Category | Test Case | Input | Expected | Priority |
|---|----------|-----------|-------|----------|----------|
| 1 | Happy | Valid create | name="Cafe ABC", category="cafe", valid media | 201, PENDING_REVIEW | P0 |
| 2 | Validation | Missing name | name="" | 400 VALIDATION_ERROR | P0 |
| 3 | Validation | Name too short | name="A" | 400 VALIDATION_ERROR | P1 |
| 4 | Validation | Name too long | 101 chars | 400 VALIDATION_ERROR | P1 |
| 5 | Validation | Invalid category | category="bar" | 400 VALIDATION_ERROR | P1 |
| 6 | Validation | Missing coordinates | No coordinates | 400 VALIDATION_ERROR | P1 |
| 7 | Media | Invalid mediaId | mediaId not in S3 | 400 INVALID_MEDIA | P0 |
| 8 | Media | Media without GPS metadata | Media has no gps-latitude | 400 INVALID_MEDIA | P0 |
| 9 | Auth | No JWT | No Authorization header | 401 UNAUTHORIZED | P0 |
| 10 | Quota | FREE user 5th create | 5 existing today | 201 (at limit) | P0 |
| 11 | Quota | FREE user 6th create | 5 existing today | 429 QUOTA_EXCEEDED | P0 |
| 12 | Quota | PRO user 15th create | 14 existing today | 201 (at limit) | P1 |
| 13 | Quota | PRO user 16th create | 15 existing today | 429 QUOTA_EXCEEDED | P1 |
| 14 | Dedup | Exact name within 100m | Same normalized name, <100m | 409 NEAR_DUPLICATE | P0 |
| 15 | Dedup | Similar name within 100m | Levenshtein ≤3, <100m | 409 NEAR_DUPLICATE | P0 |
| 16 | Dedup | Same name > 100m away | Same name, >100m | 201 (no conflict) | P1 |
| 17 | Dedup | Force create | force=true, duplicate exists | 201 (force override) | P0 |
| 18 | Dedup | Vietnamese diacritics | "Quán Cà Phê" vs "quan ca phe" | Treated as same | P0 |
| 19 | Status | Default status | Any valid create | status=PENDING_REVIEW | P0 |
| 20 | Status | Default visibility | Any valid create | visibility=FRIENDS | P0 |
| 21 | Status | Not in public search | Candidate created | Not visible in /search | P1 |

---

## 9. Deploy Checklist

```
Pre-deploy:
  □ cd services/api && npm run build
  □ cd infra/cdk && npm run build && npx cdk synth
  □ npx cdk diff → review changes
  □ Verify no breaking changes to existing resources

Deploy:
  □ npx cdk deploy --all
  □ Note new API Gateway endpoint URL

Post-deploy verification:
  □ DynamoDB: fidee-dev-places table has GSI2
  □ Lambda: fidee-dev-create-place-candidate exists
  □ API Gateway: /place-candidates route exists
  □ Test with curl:
    curl -X POST https://{api}/dev/place-candidates \
      -H "Authorization: Bearer {jwt}" \
      -H "Content-Type: application/json" \
      -d '{"name":"Test","category":"cafe","mediaId":"test","coordinates":{"lat":10.77,"lng":106.70}}'
  □ Expected: 400 INVALID_MEDIA (because mediaId doesn't exist in S3)

Mobile:
  □ flutter analyze → no new errors
  □ flutter run → verify CameraScreen navigation works
```
