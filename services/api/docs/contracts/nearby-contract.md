# GET /places/nearby — API Contract

> **Ticket**: MAP-14A / MAP-35  
> **Owner**: Minh  
> **Branch**: `MAP-14A-nearby-contract`  
> **Context**: Camera-first check-in flow  
> **Provider**: GOONG Maps  
> **Figma**: https://www.figma.com/design/SsebSYBh7Ja6wAhCYVTLCl/MapVibe?node-id=53-7

---

## 1. Overview

Khi user chụp ảnh check-in, app trích xuất GPS từ EXIF metadata của ảnh, rồi gọi API này để lấy danh sách địa điểm gần nhất. User chọn 1 địa điểm để gắn vào ảnh, hoặc tạo địa điểm mới nếu không tìm thấy.

### Camera-first Flow

```
User chụp ảnh
       ↓
App upload ảnh → nhận media_id
       ↓
App đọc GPS từ EXIF (lat/lng)
       ↓
GET /places/nearby?lat=...&lng=...&context=camera_check_in&media_id=...
       ↓
API trả về danh sách nearby places (từ GOONG)
       ↓
User chọn: "Gắn địa điểm" hoặc "Tạo mới"
```

---

## 2. Request

```
GET /places/nearby?lat={lat}&lng={lng}&radius={meters}&context=camera_check_in&media_id={media_id}
```

### Query Parameters

| Parameter | Type    | Required | Default | Description                                      |
|-----------|---------|----------|---------|--------------------------------------------------|
| `lat`     | Float   | ✅ Yes   | —       | Vĩ độ. Nguồn ưu tiên: GPS EXIF từ ảnh chụp      |
| `lng`     | Float   | ✅ Yes   | —       | Kinh độ. Nguồn ưu tiên: GPS EXIF từ ảnh chụp     |
| `radius`  | Integer | No       | `50`    | Bán kính tìm kiếm (mét). Max: 500                |
| `context` | String  | ✅ Yes   | —       | Phải là `camera_check_in` cho MVP                 |
| `media_id`| String  | ✅ Yes   | —       | ID ảnh đã upload lên S3, dùng để verify GPS proof |

### Example Request

```
GET /places/nearby?lat=10.771597&lng=106.704416&radius=50&context=camera_check_in&media_id=photo_abc123
```

---

## 3. Response Schema

### Success (200)

```jsonc
{
  "status": "success",
  "metadata": {
    "source": "goong_places",         // Provider chính
    "has_goong_fallback": true,        // true = Goong API available, false = Goong unavailable
    "total_results": 3,
    "request_lat": 10.771597,
    "request_lng": 106.704416,
    "radius_meters": 50
  },
  "data": [
    {
      "id": "string",                  // MapVibe internal ID
      "place_id": "string | null",     // GOONG place_id (null cho custom)
      "source": "goong_places | custom",
      "display_name": "string",
      "address": "string",
      "category": "string",            // cafe, restaurant, tourist_attraction, custom, ...
      "distance_meters": 12,           // Khoảng cách từ tọa độ request
      "confidence": "high | medium | low",
      "coordinates": {
        "lat": 10.771597,
        "lng": 106.704416
      },
      "actions": {
        "primary": "attach_place_to_photo | create_custom_place"
      }
    }
  ]
}
```

### Field Definitions

| Field              | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| `id`               | ID nội bộ MapVibe. Format: `place_mapvibe_{number}` hoặc `custom_fallback` |
| `place_id`         | ID gốc từ GOONG Maps. `null` cho custom place                              |
| `source`           | `goong_places` = từ Goong API. `custom` = user tự tạo (fallback)           |
| `display_name`     | Tên hiển thị chính trên UI                                                 |
| `address`          | Địa chỉ đầy đủ                                                            |
| `category`         | Phân loại: `cafe`, `restaurant`, `tourist_attraction`, `hotel`, `custom`... |
| `distance_meters`  | Khoảng cách tính từ tọa độ request (GPS ảnh). Đã sort ascending            |
| `confidence`       | Độ tin cậy: `high` (<15m), `medium` (15-35m), `low` (>35m hoặc custom)     |
| `actions.primary`  | Hành động chính cho nút CTA trên UI                                        |

### Actions

| Action                  | UI Behavior                                                    |
|-------------------------|----------------------------------------------------------------|
| `attach_place_to_photo` | Gắn place này vào ảnh check-in. Chuyển sang màn Review/Submit  |
| `create_custom_place`   | Mở form tạo địa điểm mới. User nhập tên, chọn category        |

---

## 4. Error Responses

### 400 — Missing Parameters

```json
{
  "status": "error",
  "error": {
    "code": "MISSING_PARAMS",
    "message": "Required parameters: lat, lng, context, media_id"
  }
}
```

### 400 — Invalid Context

```json
{
  "status": "error",
  "error": {
    "code": "INVALID_CONTEXT",
    "message": "context must be 'camera_check_in'"
  }
}
```

### 400 — Invalid Coordinates

```json
{
  "status": "error",
  "error": {
    "code": "INVALID_COORDINATES",
    "message": "lat must be between -90 and 90, lng must be between -180 and 180"
  }
}
```

---

## 5. Confidence Rules

| Confidence | Distance         | UI Hint                               |
|------------|------------------|---------------------------------------|
| `high`     | 0–15 meters      | Hiện badge xanh ✅. Auto-suggest đầu tiên |
| `medium`   | 15–35 meters     | Hiện bình thường                       |
| `low`      | 35–50 meters     | Hiện nhạt hơn, có text "Xa hơn"       |
| `low`      | custom fallback  | Luôn ở cuối list, icon "+" khác biệt  |

---

## 6. GOONG Fallback Behavior

| Scenario                              | `has_goong_fallback` | `data` contents                                |
|---------------------------------------|----------------------|------------------------------------------------|
| Goong trả về kết quả bình thường       | `true`               | Goong places + custom_fallback ở cuối          |
| Goong trả về 0 kết quả (khu vực vắng) | `true`               | Chỉ có `custom_fallback`                       |
| Goong API lỗi / timeout               | `false`              | Chỉ có `custom_fallback`                       |
| Tất cả Goong places cách > 50m        | `true`               | `custom_fallback` được đẩy lên top, Goong theo sau |

---

## 7. Out of Scope (MVP)

- ❌ Map-first place selection (user chọn trên bản đồ trước)
- ❌ Bedrock / KB / Semantic search
- ❌ Non-GOONG provider (Google, Mapbox, etc.)
- ❌ Pagination (max ~10 kết quả nearby đủ dùng)

---

## 8. Appendix: Mock JSON Files

Các file mock dưới đây có thể dùng trực tiếp trên Frontend/Admin để test UI:

| File | State | Mô tả |
|------|-------|-------|
| `nearby_mock_success.json` | Happy path | 3 kết quả (2 Goong + 1 custom fallback) |
| `nearby_mock_goong_down.json` | Goong unavailable | Chỉ 1 custom fallback |
| `nearby_mock_no_results.json` | Khu vực vắng | Chỉ 1 custom fallback, has_goong_fallback = true |
| `nearby_mock_error_400.json` | Missing params | Trả về error object |
