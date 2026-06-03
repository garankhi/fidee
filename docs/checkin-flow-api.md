# Check-in Flow API Checklist

Tài liệu này mô tả flow check-in theo thứ tự chạy thực tế: chụp ảnh, xin upload, upload ảnh, lấy nearby places, chọn/tạo địa điểm, tạo check-in, rồi kiểm tra feed/admin review.

## 0. Chuẩn bị token

Tất cả API protected cần header `Authorization` là Cognito `IdToken`.

```powershell
$base = "https://92idnbsaoj.execute-api.ap-southeast-1.amazonaws.com/dev"

$authJson = aws cognito-idp initiate-auth `
  --client-id 35jeemfqql648mt950s6bs3qli `
  --auth-flow USER_PASSWORD_AUTH `
  --auth-parameters USERNAME=testapi@fidee.com,PASSWORD=TestApi@123

$authObj = $authJson | ConvertFrom-Json
$token = $authObj.AuthenticationResult.IdToken
$headers = @{ "Authorization" = $token }
$jsonHeaders = @{ "Authorization" = $token; "Content-Type" = "application/json" }
```

Expected: `$token` có giá trị string JWT. Nếu rỗng, các bước sau sẽ trả `401`.

## 1. Flow A — Check-in vào địa điểm đã có

### Bước 1 — Tạo presigned upload

API: `POST /media/uploads`

Mục đích: backend tạo `mediaId` và presigned S3 POST để mobile upload ảnh kèm GPS proof.

Body:

```json
{
  "source": "IN_APP_CAMERA",
  "contentType": "image/jpeg",
  "contentLength": 245000,
  "gpsProof": {
    "latitude": 10.7738,
    "longitude": 106.7035,
    "capturedAt": "2026-06-02T16:00:00.000Z",
    "accuracyMeters": 12
  }
}
```

Test:

```powershell
$uploadBody = @{
  source = "IN_APP_CAMERA"
  contentType = "image/jpeg"
  contentLength = 245000
  gpsProof = @{
    latitude = 10.7738
    longitude = 106.7035
    capturedAt = "2026-06-02T16:00:00.000Z"
    accuracyMeters = 12
  }
} | ConvertTo-Json -Depth 10

$upload = Invoke-RestMethod -Uri "$base/media/uploads" -Headers $jsonHeaders -Method Post -Body $uploadBody
$upload | ConvertTo-Json -Depth 10
$mediaId = $upload.mediaId
```

Expected response:

```json
{
  "mediaId": "uuid",
  "upload": {
    "url": "https://...",
    "fields": { "Content-Type": "image/jpeg" }
  },
  "expiresInSeconds": 300
}
```

Lưu ý:
- `source` chỉ nhận `IN_APP_CAMERA` hoặc `EXIF_GALLERY`.
- `EXIF_GALLERY` chỉ dành cho user `PRO`.
- `contentType` chỉ nhận `image/jpeg`, `image/png`, `image/webp`.
- `contentLength` tối đa `5MB`.

### Bước 2 — Upload ảnh lên S3

API: presigned `upload.url` từ bước 1, không phải API Gateway.

Mục đích: đưa file ảnh thật lên S3 với đúng `fields` backend trả về.

Test thủ công bằng app/mobile là dễ nhất. Nếu test bằng script, cần gửi `multipart/form-data` gồm toàn bộ `$upload.upload.fields` và field `file`.

Expected:
- S3 trả `204` hoặc `201` tùy presigned POST.
- Sau upload, S3 event sẽ kích hoạt backend xử lý media uploaded.
- Nếu thiếu metadata hoặc file sai content type/size, media event sẽ bị skip.

### Bước 3 — Lấy nearby places quanh GPS ảnh

API: `GET /places/nearby?lat={lat}&lng={lng}&radius={meters}&media_id={mediaId}`

Mục đích: lấy danh sách địa điểm gần vị trí ảnh để user chọn.

Test:

```powershell
$nearby = Invoke-RestMethod -Uri "$base/places/nearby?lat=10.7738&lng=106.7035&radius=300&media_id=$mediaId" -Headers $headers -Method Get
$nearby | ConvertTo-Json -Depth 10
```

Expected response dạng chính:

```json
{
  "status": "success",
  "metadata": {
    "source": "...",
    "total_results": 1
  },
  "data": [
    {
      "id": "place-id-or-custom",
      "place_id": "place-id",
      "source": "internal",
      "display_name": "Tên địa điểm",
      "address": "Địa chỉ",
      "category": "cafe",
      "distance_meters": 45,
      "coordinates": { "lat": 10.7738, "lng": 106.7035 },
      "actions": { "primary": "check_in" }
    }
  ]
}
```

Nếu không có địa điểm phù hợp, mobile có fallback item `Tạo địa điểm mới tại đây`.

### Bước 4 — Tạo check-in với `place_id`

API: `POST /check-ins`

Mục đích: tạo check-in cho địa điểm đã tồn tại.

Body:

```json
{
  "place_id": "place-uuid",
  "media_id": "media-uuid",
  "gps_lat": 10.7738,
  "gps_lng": 106.7035,
  "gps_accuracy": 12,
  "caption": "Cafe sáng ở đây rất ổn",
  "rating": 5,
  "visibility": "PUBLIC"
}
```

Test:

```powershell
$checkinBody = @{
  place_id = "REPLACE_WITH_PLACE_ID"
  media_id = $mediaId
  gps_lat = 10.7738
  gps_lng = 106.7035
  gps_accuracy = 12
  caption = "Cafe sáng ở đây rất ổn"
  rating = 5
  visibility = "PUBLIC"
} | ConvertTo-Json -Depth 10

$checkin = Invoke-RestMethod -Uri "$base/check-ins" -Headers $jsonHeaders -Method Post -Body $checkinBody
$checkin | ConvertTo-Json -Depth 10
```

Expected response:

```json
{
  "status": "success",
  "data": {
    "id": "checkin-id",
    "created_at": "2026-06-02T16:01:00.000Z"
  }
}
```

Validation cần check:
- Phải có đúng một trong hai field `place_id` hoặc `candidate_id`.
- Không được gửi cả `place_id` và `candidate_id` cùng lúc.
- Bắt buộc có `media_id`, `gps_lat`, `gps_lng`.

### Bước 5 — Kiểm tra feed bản đồ

API: `GET /map/feed?lat={lat}&lng={lng}&radius={meters}`

Mục đích: xác nhận check-in xuất hiện trong feed/map.

Test:

```powershell
$feed = Invoke-RestMethod -Uri "$base/map/feed?lat=10.7738&lng=106.7035&radius=5000" -Headers $headers -Method Get
$feed | ConvertTo-Json -Depth 10
```

Expected: response `200`, body có `data` là danh sách item. Nếu chưa thấy item, kiểm tra lại `visibility`, vị trí, radius và dữ liệu DB.

## 2. Flow B — Check-in vào địa điểm mới do user tạo

Flow này dùng khi bước nearby không có địa điểm phù hợp và user chọn `Tạo địa điểm mới tại đây`.

### Bước 1 — Tạo presigned upload

Dùng lại `POST /media/uploads` như Flow A bước 1.

### Bước 2 — Upload ảnh lên S3

Dùng lại presigned S3 POST như Flow A bước 2.

### Bước 3 — Lấy nearby places để xác nhận không có match

Dùng lại `GET /places/nearby` như Flow A bước 3.

Expected: không có địa điểm đúng ý user hoặc có fallback `Tạo địa điểm mới tại đây`.

### Bước 4 — Tạo place candidate

API: `POST /place-candidates`

Mục đích: tạo địa điểm mới ở trạng thái chờ admin review.

Body tối thiểu:

```json
{
  "name": "Quán Cà Phê Bình Minh",
  "category": "cafe",
  "mediaId": "media-uuid",
  "coordinates": {
    "lat": 10.7738,
    "lng": 106.7035
  },
  "force": false
}
```

Body đầy đủ mobile có thể gửi:

```json
{
  "name": "Quán Cà Phê Bình Minh",
  "category": "cafe",
  "mediaId": "media-uuid",
  "coordinates": { "lat": 10.7738, "lng": 106.7035 },
  "force": false,
  "address": "123 Nguyễn Huệ, Quận 1",
  "openTime": "07:00",
  "closeTime": "22:00",
  "priceMin": 20000,
  "priceMax": 50000,
  "phoneNumber": "0909123456",
  "description": "Không gian yên tĩnh, phù hợp làm việc"
}
```

Test:

```powershell
$candidateBody = @{
  name = "Quán Cà Phê Bình Minh"
  category = "cafe"
  mediaId = $mediaId
  coordinates = @{ lat = 10.7738; lng = 106.7035 }
  force = $false
  address = "123 Nguyễn Huệ, Quận 1"
  openTime = "07:00"
  closeTime = "22:00"
  priceMin = 20000
  priceMax = 50000
  phoneNumber = "0909123456"
  description = "Không gian yên tĩnh, phù hợp làm việc"
} | ConvertTo-Json -Depth 10

$candidate = Invoke-RestMethod -Uri "$base/place-candidates" -Headers $jsonHeaders -Method Post -Body $candidateBody
$candidate | ConvertTo-Json -Depth 10
$candidateId = $candidate.data.candidate_id
```

Expected `201`:

```json
{
  "status": "created",
  "data": {
    "candidate_id": "uuid",
    "name": "Quán Cà Phê Bình Minh",
    "normalized_name": "quan ca phe binh minh",
    "category": "cafe",
    "coordinates": { "lat": 10.7738, "lng": 106.7035 },
    "status": "PENDING_REVIEW",
    "visibility": "FRIENDS",
    "created_by": "cognito-sub",
    "created_at": "2026-06-02T16:02:00.000Z"
  }
}
```

Các response cần test thêm:

```json
{
  "status": "conflict",
  "error": {
    "code": "NEAR_DUPLICATE",
    "message": "Similar place candidates found nearby"
  },
  "candidates": [
    {
      "candidateId": "candidate-id",
      "name": "Cafe Bình Minh",
      "normalizedName": "cafe binh minh",
      "distanceMeters": 45
    }
  ]
}
```

```json
{
  "status": "error",
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Daily limit reached",
    "daily_limit": 5,
    "used": 5
  }
}
```

Nếu gặp `409 NEAR_DUPLICATE` nhưng vẫn muốn tạo, gọi lại với `"force": true`.

Quota hiện tại:
- `FREE`: 5 candidates/ngày.
- `PRO`: 15 candidates/ngày.

### Bước 5 — Tạo check-in với `candidate_id`

API: `POST /check-ins`

Mục đích: check-in tạm vào candidate đang chờ review.

Body:

```json
{
  "candidate_id": "candidate-uuid",
  "media_id": "media-uuid",
  "gps_lat": 10.7738,
  "gps_lng": 106.7035,
  "gps_accuracy": 12,
  "caption": "Mình vừa tạo địa điểm này",
  "rating": 5,
  "visibility": "PUBLIC"
}
```

Test:

```powershell
$candidateCheckinBody = @{
  candidate_id = $candidateId
  media_id = $mediaId
  gps_lat = 10.7738
  gps_lng = 106.7035
  gps_accuracy = 12
  caption = "Mình vừa tạo địa điểm này"
  rating = 5
  visibility = "PUBLIC"
} | ConvertTo-Json -Depth 10

$candidateCheckin = Invoke-RestMethod -Uri "$base/check-ins" -Headers $jsonHeaders -Method Post -Body $candidateCheckinBody
$candidateCheckin | ConvertTo-Json -Depth 10
```

Expected: giống Flow A bước 4, status `201`, body có `data.id` và `data.created_at`.

## 3. Flow C — Admin duyệt candidate sau check-in

Flow này dùng để kiểm tra candidate user tạo có đi vào hàng chờ review và admin xử lý được không.

### Bước 1 — List pending candidates

API: `GET /admin/places/pending?status=PENDING_REVIEW`

Test:

```powershell
$pending = Invoke-RestMethod -Uri "$base/admin/places/pending?status=PENDING_REVIEW" -Headers $headers -Method Get
$pending | ConvertTo-Json -Depth 10
```

Expected:

```json
{
  "status": "success",
  "data": [
    {
      "id": "candidate-id",
      "name": "Quán Cà Phê Bình Minh",
      "category": "cafe",
      "coordinates": { "lat": 10.7738, "lng": 106.7035 },
      "status": "PENDING_REVIEW",
      "created_by_name": "User name"
    }
  ]
}
```

### Bước 2 — Xem chi tiết candidate

API: `GET /admin/places/candidates/{id}`

Test:

```powershell
$detail = Invoke-RestMethod -Uri "$base/admin/places/candidates/$candidateId" -Headers $headers -Method Get
$detail | ConvertTo-Json -Depth 10
```

Expected: có candidate detail, creator info, GPS proof/check-ins liên quan, duplicate hints.

### Bước 3A — Approve candidate thành place thật

API: `POST /admin/places/candidates/{id}/approve`

Body: không cần body.

Test:

```powershell
$approve = Invoke-RestMethod -Uri "$base/admin/places/candidates/$candidateId/approve" -Headers $headers -Method Post
$approve | ConvertTo-Json -Depth 10
```

Expected:

```json
{
  "status": "success",
  "data": {
    "action": "approved",
    "candidate_id": "candidate-id",
    "place_id": "new-place-id"
  }
}
```

### Bước 3B — Reject candidate

API: `POST /admin/places/candidates/{id}/reject`

Body:

```json
{ "reason": "Ảnh không đủ rõ hoặc địa điểm đã tồn tại" }
```

Test:

```powershell
$rejectBody = @{ reason = "Ảnh không đủ rõ hoặc địa điểm đã tồn tại" } | ConvertTo-Json
$reject = Invoke-RestMethod -Uri "$base/admin/places/candidates/$candidateId/reject" -Headers $jsonHeaders -Method Post -Body $rejectBody
$reject | ConvertTo-Json -Depth 10
```

Expected: candidate chuyển `REJECTED`, audit log có action `REJECTED`.

### Bước 3C — Request more info

API: `POST /admin/places/candidates/{id}/request-info`

Body:

```json
{ "note": "Vui lòng bổ sung ảnh mặt tiền và biển hiệu" }
```

Test:

```powershell
$infoBody = @{ note = "Vui lòng bổ sung ảnh mặt tiền và biển hiệu" } | ConvertTo-Json
$info = Invoke-RestMethod -Uri "$base/admin/places/candidates/$candidateId/request-info" -Headers $jsonHeaders -Method Post -Body $infoBody
$info | ConvertTo-Json -Depth 10
```

Expected: candidate chuyển `NEEDS_MORE_INFO`, `rejection_reason` lưu note.

### Bước 3D — Merge candidate vào place đã có

API: `POST /admin/places/candidates/{id}/merge`

Body:

```json
{ "targetPlaceId": "approved-place-id" }
```

Test:

```powershell
$mergeBody = @{ targetPlaceId = "REPLACE_WITH_APPROVED_PLACE_ID" } | ConvertTo-Json
$merge = Invoke-RestMethod -Uri "$base/admin/places/candidates/$candidateId/merge" -Headers $jsonHeaders -Method Post -Body $mergeBody
$merge | ConvertTo-Json -Depth 10
```

Expected: candidate bị xóa, check-ins gần candidate được trỏ sang `targetPlaceId`, audit log có action `MERGED`.

## 4. Flow D — Kiểm tra lỗi validation bắt buộc

### Case 1 — Check-in thiếu place/candidate

```powershell
$bad = @{
  media_id = $mediaId
  gps_lat = 10.7738
  gps_lng = 106.7035
} | ConvertTo-Json

Invoke-RestMethod -Uri "$base/check-ins" -Headers $jsonHeaders -Method Post -Body $bad
```

Expected: `400`, error `Either place_id or candidate_id is required`.

### Case 2 — Check-in gửi cả place và candidate

```powershell
$bad = @{
  place_id = "place-id"
  candidate_id = "candidate-id"
  media_id = $mediaId
  gps_lat = 10.7738
  gps_lng = 106.7035
} | ConvertTo-Json

Invoke-RestMethod -Uri "$base/check-ins" -Headers $jsonHeaders -Method Post -Body $bad
```

Expected: `400`, error `Use only one of place_id or candidate_id`.

### Case 3 — Candidate thiếu media GPS proof

```powershell
$badCandidate = @{
  name = "Quán Test"
  category = "cafe"
  mediaId = "not-existing-media"
  coordinates = @{ lat = 10.7738; lng = 106.7035 }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "$base/place-candidates" -Headers $jsonHeaders -Method Post -Body $badCandidate
```

Expected: `400`, error code `INVALID_MEDIA`.

## 5. Thứ tự kiểm tra đề xuất

1. Lấy token thành công.
2. Gọi `GET /profile` để chắc token hợp lệ.
3. Gọi `POST /media/uploads` lấy `mediaId`.
4. Upload file ảnh thật lên presigned S3 URL.
5. Gọi `GET /places/nearby` với `media_id=$mediaId`.
6. Nếu có `place_id`: gọi `POST /check-ins` với `place_id`.
7. Nếu không có `place_id`: gọi `POST /place-candidates`, lấy `candidate_id`, rồi gọi `POST /check-ins` với `candidate_id`.
8. Gọi `GET /map/feed` để kiểm tra item check-in.
9. Với candidate mới: gọi admin pending/detail rồi approve/reject/request-info/merge.

## 6. Ghi chú trạng thái test hiện tại

Khi chạy unit test mục tiêu trong `services/api`, các nhóm `search`, `get-profile`, `middleware/auth`, `handle-media-uploaded`, `create-media-upload` đang pass. Nhóm `create-place-candidate` hiện có test fail vì thiếu `DB_SECRET_ARN` trong môi trường local, nên nếu test local không có DB secret thì endpoint candidate có thể trả `500` thay vì `201/409/429`.
