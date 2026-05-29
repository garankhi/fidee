# Fidee Business Rules and MVP Flow

## 1. Purpose

This document defines the current Fidee MVP business flow, scope boundaries, and product rules so product, design, mobile, backend, and admin work from the same source of truth.

Fidee MVP is not a delivery app or broad public review platform. The MVP combines a simple AI-style web search experience with a camera-first social food discovery loop: users can search places quickly by keyword, and can also capture real food/place moments, attach them to a nearby place, and share them with a trusted friend circle.

## 2. Current Product Direction

Fidee combines two behavior patterns:

- Locket-style private sharing: small friend circles see each other's real activity.
- Bump-style lightweight social loop: fast posting and low-friction interaction.

Fidee applies this to food discovery through two MVP surfaces: a simple web search flow for fast discovery, and a camera-first mobile flow for real friend-based signals. The MVP does not require Bedrock, knowledge base retrieval, or complex intent parsing before launch.

Core user promise:

> Chụp món/quán đang ăn, gắn đúng địa điểm gần đó, chia sẻ cho vòng bạn bè, rồi dùng tín hiệu thật từ bạn bè để biết hôm nay nên ăn gì.

Web search promise:

> Tìm quán nhanh bằng keyword đơn giản trước, rồi nâng cấp AI search sau khi dữ liệu và hành vi người dùng đủ rõ.

## 3. MVP Product Pillars

Fidee MVP has two product pillars:

1. Simple AI-search web app: search food places by keyword/category/location-style text without Bedrock or knowledge base integration.
2. Camera-first social discovery: capture in-app photo, attach nearby place, and share friends-only.

The search pillar helps users discover quickly. The camera-first pillar creates trusted social data that can make later AI recommendations better.

## 4. MVP Primary Mobile Flow: Camera First

For MVP, Fidee supports one main creation flow only: camera-first check-in.

```text
User taps camera
-> App captures photo in-app
-> App captures GPS proof at photo time
-> App uploads or creates media draft
-> App calls GET /places/nearby using captured GPS
-> User selects nearby place or creates custom place candidate
-> App creates check-in post attached to photo and selected place
-> Friends can view, comment, and upvote
```

This means place selection happens after photo capture, not before.

### MAP-31 Media Upload Rules

Media ingestion is split into two backend steps:

```text
Mobile requests upload
-> POST /media/uploads validates auth, source, MIME, size, and GPS proof
-> Backend checks user plan from UserProfilesTable
-> Backend returns presigned S3 POST
-> Mobile uploads image bytes directly to S3
-> S3 ObjectCreated emits EventBridge event
-> EventBridge routes uploads/ events to SQS + DLQ
-> Worker Lambda reads S3 metadata with HeadObject
-> Worker revalidates metadata/object and creates Media PENDING_MODERATION
```

Rules:

- API Gateway/Lambda must not proxy image bytes.
- Allowed upload sources are `IN_APP_CAMERA` and `EXIF_GALLERY`.
- Free users can use `IN_APP_CAMERA` only.
- Pro users can use both `IN_APP_CAMERA` and `EXIF_GALLERY`.
- `UserProfilesTable` is the server-side source of truth for plan; missing/unknown plan means Free.
- Allowed MIME types are `image/jpeg`, `image/png`, and `image/webp`.
- Maximum upload size is 5MB for MVP.
- GPS proof must include latitude, longitude, and source; timestamp and accuracy are stored when available.
- Presigned POST must bind exact S3 key, content type, signed metadata, and 1-5MB content-length range.
- Worker must create `Media` idempotently by `mediaId` because S3/EventBridge/SQS can deliver duplicates.
- Invalid/tampered object metadata should not create `Media`; infrastructure retry failures go to DLQ.

## 5. MVP Web Flow: Simple Search First

For MVP, AI search means lightweight keyword-based search, not full LLM search.

```text
User opens web app
-> User types keyword/category/location-style query
-> App searches Fidee place data with simple matching
-> App shows place results
-> User opens place detail or saves/shares if authenticated
```

MVP search may support simple keyword fields such as place name, category, address, tags, and basic text query. Bedrock, knowledge base retrieval, semantic search, complex prompt parsing, and AI-generated answers are deferred.

## 6. Deferred Flow: Map First

Map-first browsing and check-in are not part of MVP.

Deferred flow:

```text
User opens map
-> User selects place first
-> User takes photo/checks in at selected place
```

Reason for deferral:

- Camera-first is closer to the social sharing habit Fidee wants to validate.
- One flow reduces MVP design, mobile, backend, and QA scope.
- Nearby place resolver can still be designed in a reusable way for map-first later.

## 7. Place Selection Rules

### BR-PLACE-01: Place selection requires GPS proof

Every check-in must be tied to GPS captured by the app during the camera session. User-entered latitude or longitude is not accepted for creating check-ins or custom place candidates.

### BR-PLACE-02: Nearby resolver runs after capture in MVP

For MVP, `GET /places/nearby` is called after photo capture using the photo GPS proof. Mobile should not design MVP around choosing a place before taking a photo.

### BR-PLACE-03: Fidee data is source of truth

Fidee `Place` and `PlaceCandidate` records are the product source of truth. GOONG Places can be used as fallback/reference, but GOONG data must not become the primary database by default.

### BR-PLACE-04: Public places are controlled

`Place` records are public and searchable. They can be created only by seed data, admin approval, or admin merge from a candidate.

### BR-PLACE-05: Custom places are not public by default

User-created custom places become `PlaceCandidate` records with friends-visible scope by default. They must not appear in public discovery until approved or merged by admin.

### BR-PLACE-06: Duplicate prevention is server-side

Before creating a custom place candidate, backend checks for duplicates within the configured radius. If normalized name similarity is high enough, user must choose an existing result or submit for merge instead of creating a duplicate.

### BR-PLACE-07: GOONG place ID is external reference only

If a GOONG `place_id` already maps to an existing `Place` or `PlaceCandidate`, backend must not create a duplicate record.

## 8. Nearby Resolver Contract Rules

`GET /places/nearby` supports the camera-first place selection screen.

MVP request shape:

```http
GET /places/nearby?lat={lat}&lng={lng}&radius={meters}&context=camera_check_in&media_id={media_id}
Authorization: Bearer <jwt>
```

Rules:

- `lat` and `lng` come from app-captured GPS proof.
- `radius` defaults to `100` meters.
- `radius` maximum is `300` meters for MVP.
- `context` must be `camera_check_in` for MVP UI.
- `media_id` is optional only if backend has not created media draft before place selection.

Each result must include these fields:

| Field | Meaning | Design usage |
|---|---|---|
| `source` | Data source: Fidee place, friend candidate, or GOONG fallback. | Badge, admin/debug state. |
| `confidence` | Backend confidence from `0` to `1`. | Sorting, weak-match warning, admin review. |
| `distance_meters` | Distance from captured GPS to result. | Nearby label. |
| `display_name` | User-facing place name. | Primary row title. |
| `category` | Food/place category. | Filter chip, icon, secondary label. |
| `address` | Short readable address. | Secondary row copy. |

Recommended ranking:

1. Exact Fidee `Place` match.
2. Friends-visible `PlaceCandidate` from mutual friend circle.
3. High-confidence GOONG fallback.
4. Low-confidence GOONG fallback.

## 9. Mock JSON for Mobile and Admin

### Mobile camera-first response

```json
{
  "query": {
    "lat": 10.776889,
    "lng": 106.700806,
    "radius": 100,
    "context": "camera_check_in",
    "media_id": "med_01J0CAMERA001"
  },
  "results": [
    {
      "id": "plc_01J0PLACE001",
      "entity_type": "place",
      "source": "fidee_place",
      "confidence": 0.98,
      "distance_meters": 24,
      "display_name": "Cơm Tấm Ba Ghiền",
      "category": "restaurant",
      "address": "84 Đặng Văn Ngữ, Phú Nhuận, TP.HCM",
      "location": {
        "lat": 10.777012,
        "lng": 106.700621
      },
      "visibility": "PUBLIC",
      "can_attach_to_media": true,
      "can_check_in": true
    },
    {
      "id": "pcd_01J0CANDIDATE001",
      "entity_type": "place_candidate",
      "source": "friend_candidate",
      "confidence": 0.9,
      "distance_meters": 41,
      "display_name": "Quán bún bò chị Lan",
      "category": "restaurant",
      "address": "Gần hẻm 92 Đặng Văn Ngữ, Phú Nhuận, TP.HCM",
      "location": {
        "lat": 10.776601,
        "lng": 106.700931
      },
      "visibility": "FRIENDS_VISIBLE",
      "created_by_friend": {
        "user_id": "usr_01J0FRIEND001",
        "display_name": "Hân"
      },
      "can_attach_to_media": true,
      "can_check_in": true
    },
    {
      "id": "gng_01J0GOONGPLACE001",
      "entity_type": "external_place",
      "source": "goong_places",
      "confidence": 0.82,
      "distance_meters": 73,
      "display_name": "Highlands Coffee",
      "category": "cafe",
      "address": "Phú Nhuận, TP.HCM",
      "location": {
        "lat": 10.77631,
        "lng": 106.70054
      },
      "external": {
        "provider": "goong",
        "place_id": "gng_01J0GOONGPLACE001"
      },
      "can_attach_to_media": true,
      "can_check_in": true
    }
  ],
  "actions": {
    "primary": "attach_place_to_photo",
    "fallback": "create_custom_place"
  },
  "meta": {
    "result_count": 3,
    "has_goong_fallback": true,
    "default_radius": 100,
    "max_radius": 300
  }
}
```

### Empty or weak-match mobile response

```json
{
  "query": {
    "lat": 10.776889,
    "lng": 106.700806,
    "radius": 100,
    "context": "camera_check_in",
    "media_id": "med_01J0CAMERA002"
  },
  "results": [],
  "actions": {
    "primary": "create_custom_place",
    "fallback": "increase_radius"
  },
  "meta": {
    "result_count": 0,
    "has_goong_fallback": false,
    "message": "No nearby place matched with enough confidence."
  }
}
```

### Admin review response shape

```json
{
  "candidate": {
    "id": "pcd_01J0CANDIDATE001",
    "entity_type": "place_candidate",
    "source": "friend_candidate",
    "confidence": 0.9,
    "distance_meters": 41,
    "display_name": "Quán bún bò chị Lan",
    "category": "restaurant",
    "address": "Gần hẻm 92 Đặng Văn Ngữ, Phú Nhuận, TP.HCM",
    "status": "FRIENDS_VISIBLE",
    "evidence": {
      "media_id": "med_01J0CAMERA001",
      "created_by_user_id": "usr_01J0USER001",
      "created_at": "2026-05-26T10:00:00Z"
    }
  },
  "possible_duplicates": [
    {
      "id": "plc_01J0PLACE001",
      "entity_type": "place",
      "display_name": "Bún Bò Lan",
      "source": "fidee_place",
      "confidence": 0.87,
      "distance_meters": 38,
      "address": "Phú Nhuận, TP.HCM"
    }
  ],
  "admin_actions": [
    "approve_as_public_place",
    "merge_into_existing_place",
    "reject_with_reason",
    "request_more_evidence"
  ]
}
```

## 10. Social Visibility Rules

### BR-SOCIAL-01: Friends-only means mutual friends only

Friends-only posts, saved lists, and place candidates are visible only to accepted mutual friends unless promoted to public through admin review.

### BR-SOCIAL-02: Check-in post needs media and place

A check-in post must have approved or pending media plus one selected `Place` or `PlaceCandidate`.

### BR-SOCIAL-03: Feed is built from friend activity

MVP feed should prioritize recent friend check-ins and saved places. It should not require public trending or AI recommendation to work.

## 11. Search Scope Rules

### BR-SEARCH-01: MVP search is simple keyword search

For MVP, search should work with simple query matching over available place fields. It should not require Bedrock, a knowledge base, vector search, or complex AI orchestration.

### BR-SEARCH-02: Search can be branded as AI-assisted only if expectations stay simple

Product/design may present search as smart or AI-ready, but MVP behavior must be clear: it finds matching places from existing data and does not answer complex natural-language prompts yet.

### BR-SEARCH-03: Social data supports later AI

Camera-first check-ins, saved places, comments, and upvotes should be modeled so later AI recommendations can use them, but MVP should not block on that AI layer.

## 12. Monetization Scope

Free MVP includes:

- Simple keyword-based web search.
- Camera-first check-in.
- Nearby place selection.
- Add friends.
- Friends-only sharing.
- Save places to personal list/map.

Deferred monetization:

- Pro upload-later UX for photos captured at the place with location enabled.
- Higher AI question quota, for example free 3/day and pro 20/day.
- Shop boost in AI search only after user base and quality controls are strong enough.

MVP must not depend on paid features to feel useful.

## 13. Design Scope Guide

Design should focus on these MVP screens first:

1. Web search page with simple keyword search.
2. Web search results/place detail basics.
3. Camera capture screen.
4. Place selection bottom sheet after capture.
5. Custom place candidate creation screen.
6. Check-in preview/post screen.
7. Friends feed.
8. Saved food list/my map.
9. Admin moderation queue for candidates and duplicates.

Design should defer these screens:

- Public web landing experience.
- Map-first browse/check-in flow.
- Bedrock/KB-powered AI search prompt flow.
- Shop paid boost dashboard.
- Full public review marketplace.

## 14. MVP Scope Checklist

Use this checklist before adding work to MVP:

- Does it support camera-first check-in?
- Or does it support simple keyword-based web search?
- Does it use app-captured GPS proof?
- Does it help user attach a photo to the correct place?
- Does it preserve friends-only privacy?
- Does it avoid auto-publishing unverified places?
- Does it avoid making GOONG the main source of truth?
- Can design, mobile, backend, and admin test it without building map-first first?

If answer is no for most items, it is likely out of MVP scope.
