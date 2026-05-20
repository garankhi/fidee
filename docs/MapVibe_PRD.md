# Product Requirements Document (PRD): MapVibe

## 1. Document Control

| Field | Details |
|---|---|
| **Product / Project Name** | MapVibe |
| **Version** | 1.0.0 |
| **Owner** | Nguyễn Thế Minh (Product / Tech Lead) |
| **Created Date** | October 2025 |
| **Status** | Approved |

## 2. Executive Summary

### 2.1 Product Overview
MapVibe is an intelligent, AI-driven map discovery web platform that helps diners and explorers find suitable locations by translating natural language prompts into structured search parameters. It leverages Amazon Bedrock and a serverless AWS architecture to provide personalized, scalable, and intelligent location discovery.

### 2.2 Problem Statement
Conventional map platforms (e.g., Google Maps) rely heavily on static filters and basic keyword searches (e.g., "nearby restaurants"). They struggle to process nuanced, context-rich human intent like *"find a luxury rooftop restaurant with a city view open until midnight."*

### 2.3 Proposed Solution
MapVibe bridges the gap between human intent and map-based data retrieval. Users can express their needs in natural language, and the AI engine interprets the context (mood, time, purpose). The platform also features AI-summarized place overviews, user-generated reviews, and robust content moderation.

## 3. Goals and Non-Goals

### 3.1 Goals
| Goal ID | Goal | Success Metric |
|---|---|---|
| G-01 | Accurate Natural Language Search | >90% successful AI intent parsing rate |
| G-02 | Optimize Cloud Infrastructure Costs | Maintain <$200 AWS budget over 8 weeks (95% cache hit rate) |
| G-03 | Ensure Safe User-Generated Content | 100% of uploaded images pass automated moderation |

### 3.2 Non-Goals
| Non-Goal ID | Description | Reason |
|---|---|---|
| NG-01 | In-app food delivery or reservations | Out of scope for discovery MVP. Focus is purely on search and curation. |
| NG-02 | Real-time chat between users | Increases architectural complexity and moderation overhead unnecessarily. |

## 4. Target Users and Personas

| Persona / Role | Characteristics | Main Needs & Permissions |
|---|---|---|
| **Guest / Registered User (Diners)** | Looking for specific dining experiences based on mood/context. | Search via prompt, view AI summaries. Registered users can submit reviews, upload photos, and suggest places. |
| **Moderator (Community Team)** | Ensures platform quality and accuracy. | Approve/reject new place suggestions and resolve reported reviews. |
| **Admin (Ops / Platform)** | Manages the overall system health and users. | Configure system, manage users, assign badges, observe CloudWatch metrics. |

## 5. Feature Requirements & Scope

### 5.1 In Scope for MVP
* Natural language prompt-based search powered by Amazon Bedrock.
* Category and trending searches based on engagement algorithms.
* Place details pages with automated AI summarizations (7-day refresh).
* User content generation: Reviews, image uploads (with Rekognition moderation), and place suggestions.
* Admin and Moderator dashboards.
* Gamification: Automated badge assignments (Bronze, Silver, Gold).

## 6. Detailed Functional Requirements

### 6.1 Search & Discovery
**FR-01: Prompt-Based Search (Core Feature)**
* **Description:** Accepts a text prompt, utilizes Bedrock LLM to extract structured filters (cuisine, price, location, mood), and queries DynamoDB using a geo-index.
* **Acceptance Criteria:**
    * System successfully sanitizes prompt for safety before sending to Bedrock.
    * Identical prompts within 24 hours return cached responses to save AI token costs.
    * Guest users can perform searches without authentication.

**FR-03: Trending and Recommendation Feed**
* **Description:** Displays a horizontal carousel of highly-rated/visited restaurants updated daily.
* **Acceptance Criteria:** Trending weight must be calculated as `(views * rating * recency)` via EventBridge nightly cron job.

### 6.2 Restaurant Details & AI Integration
**FR-04 & FR-15: View Details & AI Summarization**
* **Description:** Displays basic info, photos, reviews, and an AI-generated overview of the place.
* **Acceptance Criteria:** AI summary must automatically refresh if the text is > 7 days old or if the place receives > 10 new reviews.

### 6.3 User-Generated Content & Moderation
**FR-07: Write a Review & Photo Upload**
* **Description:** Authenticated users can submit text, ratings (Food, Price, Service), and photos via presigned S3 URLs.
* **Acceptance Criteria:**
    * System restricts users to 1 active review per restaurant.
    * Uploaded photos must pass AWS Rekognition checks for NSFW/disallowed content.

**FR-10: Suggest New Place**
* **Description:** Users can submit new locations for the map.
* **Acceptance Criteria:** System must run deduplication logic comparing normalized names and a 100m geo-radius before marking as "pending" for moderators.

## 7. Business Rules

| Rule ID | Rule | Applies To |
|---|---|---|
| BR-04 / 05 | Only authenticated users can review; limited to ONE review per place per user. | Registered Users |
| BR-08 | All images must pass Rekognition moderation automatically. | System |
| BR-10 | Users can edit a review freely within 24 hours; edits after 24h require Moderator re-approval. | Users / Moderators |
| BR-13 | Cached AI query results must be reused for identical prompts within a 24-hour window to minimize cost. | System |

## 8. System Architecture & Constraints

### 8.1 Technical Architecture
MapVibe is a serverless, event-driven web application on AWS (ap-southeast-1). Key components include:
* **Edge & API:** Route 53, CloudFront, WAF, API Gateway.
* **Compute:** AWS Lambda microservices, EventBridge for chron jobs.
* **Data & Storage:** DynamoDB (stateless API persistence), S3 (media storage).
* **AI & Security:** Amazon Bedrock, Rekognition, Cognito (JWT Auth).

### 8.2 Non-Functional Requirements
* **Performance:** Results cached for 10 minutes (Category) or 24 hours (Prompt). 95% AI cache hit rate expected.
* **Security:** Least-privilege IAM policies, prompt-injection sanitization for Bedrock, Token expiry auto sign-out.

## 9. Cost & Budget Management (Crucial Constraint)

The project operates under a strict **$200 USD** budget for an 8-week cycle.

| Scenario | Description | Est. Cost |
|---|---|---|
| **Recommended Target** | 150 users, 92% cache hit rate | $82 |

**Key Optimizations Implemented:** On-Demand DynamoDB, Aggressive Bedrock Caching (lowers AI costs from $120 to <$1), Batch Rekognition processing, and Environment Variables in Lambda (bypassing Secrets Manager costs).
