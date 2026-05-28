# Product Requirements Document (PRD): MapVibe

## 1. Document Control

| Field | Details |
|---|---|
| **Product / Project Name** | MapVibe |
| **Version** | 1.0.0 |
| **Owner** | Nguyễn Thế Minh (Product / Tech Lead) |
| **Created Date** | October 2025 |
| **Status** | Approved |
| **MVP Business Rules** | See `docs/MapVibe_Business_Rules.md` |

## 2. Executive Summary

### 2.1 Product Overview
MapVibe MVP is an AI-search web app paired with a camera-first social food discovery mobile flow. Users can search food places quickly with simple keyword-based search, and can also capture a real food/place moment in the app, attach the photo to a nearby place using GPS proof, and share it with a trusted friend circle. The MVP keeps AI search lightweight first: keyword matching over MapVibe place data, without Bedrock, knowledge base retrieval, or complex intent parsing.

### 2.2 Problem Statement
Conventional map and review platforms are too broad for quick food decisions. Users need a fast way to search places, but they also still ask friends where to eat because public reviews can feel generic, seeded, or disconnected from their own taste circle.

### 2.3 Proposed Solution
MapVibe combines simple search and real check-ins by friends. The MVP validates two loops: keyword-based place discovery on web, and private social food sharing on mobile. Bedrock-powered natural-language search, AI summaries, semantic knowledge base retrieval, and shop monetization are later phases after the core data and social loop are useful.

## 3. Goals and Non-Goals

### 3.1 Goals
| Goal ID | Goal | Success Metric |
|---|---|---|
| G-01 | Provide fast food place discovery | Users can search places by simple keyword/category/location-style text |
| G-02 | Validate camera-first food check-in loop | Users can capture photo, select nearby place, and publish friends-only check-in |
| G-03 | Build trusted friend-based food discovery | Friends can view, comment, upvote, and save shared places |
| G-04 | Ensure safe user-generated content | 100% of uploaded images pass automated moderation |
| G-05 | Optimize cloud and provider costs | Maintain <$200 AWS budget over 8 weeks with GOONG/SMS quota guardrails |

### 3.2 Non-Goals
| Non-Goal ID | Description | Reason |
|---|---|---|
| NG-01 | In-app food delivery or reservations | Out of scope for discovery MVP. Focus is purely on search and curation. |
| NG-02 | Real-time chat between users | Increases architectural complexity and moderation overhead unnecessarily. |
| NG-03 | Map-first check-in flow | Deferred to keep MVP focused on camera-first creation. |
| NG-04 | Bedrock/KB-powered natural-language search | Phase 2. MVP search uses simple keyword matching first. |
| NG-05 | Paid shop boost dashboard | Requires enough users and quality controls before monetization. |

## 4. Target Users and Personas

| Persona / Role | Characteristics | Main Needs & Permissions |
|---|---|---|
| **Search User (Web)** | Wants a fast way to find food places. | Search by keyword/category/location-style text, view place results and details. |
| **Registered User (Diners)** | Shares food moments with friends and looks for trusted friend-based recommendations. | Capture in-app photos, attach nearby places, create friends-only check-ins, save places, suggest custom places. |
| **Friend Viewer** | Consumes check-ins from mutual friends. | View feed, comment, upvote, save places shared by friends. |
| **Moderator (Community Team)** | Ensures place quality and safety. | Review custom place candidates, duplicate matches, media moderation, and public promotion requests. |
| **Admin (Ops / Platform)** | Manages system health, data quality, and guardrails. | Configure system, manage users, review audit logs, observe CloudWatch metrics, monitor cost/quota. |

## 5. Feature Requirements & Scope

### 5.1 In Scope for MVP
* Web app with simple keyword-based food place search.
* Basic place result and place detail experience.
* Flutter Android-first camera capture flow.
* GPS proof captured by the app during photo capture.
* Nearby place resolver after capture: `GET /places/nearby` with `context=camera_check_in`.
* Place selection from public `Place`, friends-visible `PlaceCandidate`, and guarded GOONG fallback.
* Custom place candidate creation when nearby results are incorrect or missing.
* Friends-only check-in feed with comment/upvote.
* Saved food list/my map for places and candidates.
* Rekognition moderation for uploaded media.
* Admin/moderator review for candidate approval, merge, reject, and duplicate handling.

## 6. Detailed Functional Requirements

### 6.1 Search & Discovery
**FR-01: Simple Keyword Search**
* **Description:** Users can search MapVibe places quickly from the web app using simple text input.
* **Acceptance Criteria:**
    * Search supports simple keyword/category/location-style query over available place data.
    * Search does not require Bedrock, knowledge base retrieval, vector search, or complex prompt parsing for MVP.
    * Results show place name, category, address, and enough metadata for a basic place detail page.

### 6.2 Camera-First Check-In
**FR-02: In-App Camera Capture**
* **Description:** Authenticated users start the MVP creation loop from the camera, not from map-first browsing.
* **Acceptance Criteria:**
    * Mobile opens camera from the main action.
    * App captures GPS, timestamp, and accuracy at photo time.
    * App does not accept manually entered lat/lng for check-in creation.

**FR-03: Media Upload and Moderation**
* **Description:** Captured media is uploaded through a controlled flow and checked for safety.
* **Acceptance Criteria:**
    * Backend exposes protected `POST /media/uploads` and returns a presigned S3 POST for authenticated users.
    * Presigned POST only allows `image/jpeg`, `image/png`, or `image/webp`, with maximum upload size 5MB.
    * Upload metadata must include `mediaId`, owner user id, source, latitude, longitude, and optional captured timestamp and accuracy.
    * Free users can upload `IN_APP_CAMERA` media but cannot upload `EXIF_GALLERY` media.
    * Pro users can upload both `IN_APP_CAMERA` and `EXIF_GALLERY` media.
    * S3 object-created events flow through EventBridge, SQS, and a worker Lambda before creating `Media` with `PENDING_MODERATION`.
    * Disallowed or unmoderated content cannot become visible in friends feed.

### 6.3 Nearby Place Selection
**FR-04: Camera Context Nearby Resolver**
* **Description:** After photo capture, app calls `GET /places/nearby` using captured GPS to help user attach the photo to the correct place.
* **Acceptance Criteria:**
    * Request supports `lat`, `lng`, `radius`, `context=camera_check_in`, and optional `media_id`.
    * Radius defaults to 100 meters and is capped at 300 meters for MVP.
    * Results include public `Place`, friends-visible `PlaceCandidate`, and guarded GOONG fallback when needed.
    * Each result includes `source`, `confidence`, `distance_meters`, `display_name`, `category`, and `address`.

**FR-05: Custom Place Candidate Creation**
* **Description:** If no nearby result is correct, user can create a custom place candidate from the captured GPS proof.
* **Acceptance Criteria:**
    * Candidate is friends-visible by default.
    * Backend checks duplicate places/candidates before creation.
    * Candidate does not become public without admin approval or merge.

### 6.4 Social Discovery
**FR-06: Friends-Only Check-In Feed**
* **Description:** Friends see check-ins shared by mutual friends.
* **Acceptance Criteria:**
    * Check-in post includes media plus selected `Place` or `PlaceCandidate`.
    * Only mutual friends can view friends-only posts.
    * Friends can comment and upvote.

**FR-07: Saved Food List / My Map**
* **Description:** Users can save public places or eligible friends-visible candidates to a personal list/map.
* **Acceptance Criteria:**
    * Saved items are not duplicated for the same user/place.
    * Saved visibility respects place/candidate permissions.

### 6.5 Admin and Moderation
**FR-08: Candidate Review and Merge**
* **Description:** Admin/moderator reviews place candidates and duplicate suggestions before public promotion.
* **Acceptance Criteria:**
    * Admin can approve, merge, reject, or request more evidence.
    * Reject and merge actions require reason.
    * Admin decisions write audit logs.

## 7. Business Rules

| Rule ID | Rule | Applies To |
|---|---|---|
| BR-01 | MVP creation flow is camera-first. Map-first check-in is deferred. | Mobile / Product |
| BR-02 | MVP web search is simple keyword matching, not Bedrock/KB-powered prompt search. | Web / Backend |
| BR-03 | Check-ins and custom place candidates require app-captured GPS proof. | Mobile / Backend |
| BR-04 | Custom places are `PlaceCandidate` records and are friends-visible by default. | Backend / Admin |
| BR-05 | Public `Place` records require seed, admin approval, or admin merge. | Admin / Data |
| BR-06 | Friends-only content is visible only to accepted mutual friends. | Backend / Mobile |
| BR-07 | GOONG Places is fallback/reference only, not source of truth. | Backend / Data |
| BR-08 | Admin approve, reject, and merge decisions must write audit logs. | Admin / Backend |

Full business rule details, mock nearby JSON, and design scope guidance live in `docs/MapVibe_Business_Rules.md`.

## 8. System Architecture & Constraints

### 8.1 Technical Architecture
MapVibe is a serverless, event-driven web application on AWS (ap-southeast-1). Key components include:
* **Edge & API:** Route 53, CloudFront, WAF, API Gateway.
* **Compute:** AWS Lambda microservices, EventBridge for routing upload events and scheduled jobs, SQS for retryable async processing.
* **Data & Storage:** DynamoDB for places, profiles, and media records; S3 for direct media uploads.
* **AI & Security:** Amazon Bedrock for later AI phases, Rekognition, Cognito JWT auth, and source-based media license checks.

### 8.2 Non-Functional Requirements
* **Performance:** Simple search and nearby resolver should return quickly enough for MVP UI. Nearby resolver should avoid unnecessary GOONG fallback calls.
* **Security:** Least-privilege IAM policies, Cognito token expiry auto sign-out, no hardcoded API keys, and no manual lat/lng bypass for GPS proof flows.

## 9. Cost & Budget Management (Crucial Constraint)

The project operates under a strict **$200 USD** budget for an 8-week cycle.

| Scenario | Description | Est. Cost |
|---|---|---|
| **Recommended Target** | 150 users, 92% cache hit rate | $82 |

**Key Optimizations Implemented:** On-Demand DynamoDB, Aggressive Bedrock Caching (lowers AI costs from $120 to <$1), Batch Rekognition processing, and Environment Variables in Lambda (bypassing Secrets Manager costs).
