# POST /place-candidates — API Contract

> **Ticket**: MAP-15 / MAP-41
> **Owner**: ty ty (Backend), Nguyễn Thế Minh (Mobile)
> **Context**: Camera-first check-in flow — custom place creation
> **Provider**: Internal PostgreSQL/PostGIS

---

## 1. Overview

Khi user không tìm thấy địa điểm phù hợp trong nearby results, tap "Tạo địa điểm mới tại đây" → mobile mở form nhập tên + chọn category → POST request tới endpoint này.

Backend xử lý: validate input, verify media GPS proof khi `mediaId` được gửi, normalize tên, check duplicate, enforce quota, tạo candidate.

### Flow

```
NearbyPlacesSheet → "Tạo địa điểm mới"
       ↓
CreatePlaceScreen (nhập tên + category)
       ↓
POST /place-candidates
       ↓
Backend: validate → quota check → dedup → create
       ↓
Response: 201 created | 409 conflict | 429 quota
```

---

## 2. Request

```
POST /place-candidates
Authorization: Bearer {Cognito JWT}
Content-Type: application/json
```

### Request Body

```json
{
  "name": "Quán Cà Phê Bình Minh",
  "category": "cafe",
  "mediaId": "photo-uuid-abc-123",
  "coordinates": {
    "lat": 10.771597,
    "lng": 106.704416
  },
  "visibility": "FRIENDS",
  "force": false
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | ✅ Yes | Tên địa điểm. Min 2, max 100 ký tự |
| `category` | String | ✅ Yes | Phân loại (xem bảng dưới) |
| `mediaId` | String | No | ID ảnh đã upload. Nếu gửi lên, backend verify GPS proof; nếu bỏ trống, candidate dùng `coordinates` request |
| `coordinates.lat` | Float | ✅ Yes | Vĩ độ (-90 to 90) |
| `coordinates.lng` | Float | ✅ Yes | Kinh độ (-180 to 180) |
| `visibility` | String | No | `FRIENDS` mặc định; `PRIVATE` chỉ creator thấy |
| `force` | Boolean | No | `true` = tạo dù có near-duplicate |

### Categories

| Value | Label | Icon |
|-------|-------|------|
| `cafe` | Cafe | ☕ |
| `restaurant` | Nhà hàng | 🍜 |
| `hotel` | Khách sạn | 🏨 |
| `tourist_attraction` | Du lịch | 📸 |
| `office` | Văn phòng | 🏢 |
| `shopping` | Mua sắm | 🛒 |
| `other` | Khác | 📍 |

---

## 3. Response Schema

### 201 — Created

```json
{
  "status": "created",
  "data": {
    "candidate_id": "cand_abc123def456",
    "name": "Quán Cà Phê Bình Minh",
    "normalized_name": "quan ca phe binh minh",
    "category": "cafe",
    "coordinates": { "lat": 10.771597, "lng": 106.704416 },
    "status": "PENDING_REVIEW",
    "visibility": "FRIENDS",
    "created_by": "cognito-user-sub-id",
    "created_at": "2026-05-30T12:00:00Z"
  }
}
```

### 409 — Near-Duplicate Conflict

```json
{
  "status": "conflict",
  "error": {
    "code": "NEAR_DUPLICATE",
    "message": "Similar place candidates found nearby"
  },
  "candidates": [
    {
      "candidateId": "cand_existing_001",
      "name": "Cafe Bình Minh",
      "normalizedName": "cafe binh minh",
      "distanceMeters": 45
    }
  ]
}
```

### 429 — Quota Exceeded

```json
{
  "status": "error",
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Daily limit reached (5 candidates/day for FREE plan)",
    "daily_limit": 5,
    "used": 5
  }
}
```

### 400 — Validation Error

```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "name is required and must be at least 2 characters"
  }
}
```

### 400 — Invalid Media

```json
{
  "status": "error",
  "error": {
    "code": "INVALID_MEDIA",
    "message": "Media not found or missing GPS proof"
  }
}
```

---

## 4. Backend Logic

### Dedup Rules
- Normalize name: remove Vietnamese diacritics, lowercase, collapse whitespace
- Encode geohash (4-char precision ≈ 20km cell)
- Query 9 geohash neighbors via DynamoDB GSI2
- Filter candidates within 100m (Haversine distance)
- Compare normalized names: Levenshtein distance ≤ 3 OR exact match
- If match → 409

### Quota Rules

| Plan | Daily Limit |
|------|-------------|
| FREE | 5 |
| PRO | 50 |

### GPS Proof Validation
- Nếu request có `mediaId`, backend verify S3 object và GPS metadata bằng HeadObject
- Nếu request không có `mediaId`, backend bỏ qua media verification và dùng `coordinates` trong request

### DynamoDB Schema

```
PlacesTable (fidee-{stage}-places):

PK: CANDIDATE#{candidateId}    SK: META
GSI1PK: USER_CANDIDATES#{userId}    GSI1SK: {YYYY-MM-DD}#{candidateId}
GSI2PK: GEO#{geohash4}    GSI2SK: CANDIDATE#{normalizedName}#{candidateId}
```

---

## 5. Default Behavior

- Status: `PENDING_REVIEW` (không public cho đến khi admin approve)
- Visibility: `FRIENDS` by default.
- `PRIVATE` candidates are returned only to their creator.
- Candidates không xuất hiện trong public search.

---

## 6. PATCH /place-candidates/{id}

Authenticated by Cognito. Only the creator can update a candidate.

```json
{
  "address": "12 Nguyen Hue",
  "openTime": "08:00",
  "closeTime": "22:00",
  "priceMin": 25000,
  "priceMax": 70000,
  "phoneNumber": "0900000000",
  "description": "Yen tinh",
  "visibility": "PRIVATE"
}
```

Behavior:

- Accepts partial updates for candidate detail fields.
- Accepts only `FRIENDS` or `PRIVATE` visibility.
- Returns 403 when requester is not `created_by`.
- Updates `updated_at` and keeps candidate in `PENDING_REVIEW`.

---

## 7. Out of Scope (MVP)

- Admin approval/rejection endpoint polish
- Delete candidate
- Image moderation (Rekognition)
- AI categorization (Bedrock)

