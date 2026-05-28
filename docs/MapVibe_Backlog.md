# MapVibe - Social Discovery MVP Backlog v2

## 1. Tổng quan

MapVibe MVP v1 là AI-search web app đi kèm mobile social discovery cho ăn uống. Web app cho user tìm quán nhanh bằng keyword/category/location-style text đơn giản. Mobile app cho user mở app tại quán, chụp ảnh bằng camera trong app, scan khu vực xung quanh để chọn địa điểm có sẵn hoặc tạo địa điểm tùy chỉnh, rồi lưu vào bản đồ/danh sách quán của mình để bạn bè xem.

MVP vẫn giữ hướng AI search, nhưng bản đầu làm nhẹ bằng keyword/simple search, chưa tích hợp Bedrock, knowledge base, semantic search hoặc prompt parsing phức tạp. Lõi social discovery là vòng lặp:

1. Chụp ảnh/check-in tại quán.
2. Gợi ý địa điểm gần đó.
3. Chọn địa điểm có sẵn hoặc tạo địa điểm tùy chỉnh.
4. Lưu vào danh sách cá nhân và chia sẻ friends-only.
5. Bạn bè tương tác bằng comment/upvote.
6. Nếu địa điểm đủ tín hiệu chất lượng, user có thể đề xuất công khai.
7. Admin duyệt/merge/reject trước khi địa điểm thành public place.

### 1.1 Quyết định đã chốt

- **Nền tảng MVP:** Flutter Android first.
- **Backend:** AWS serverless, event-driven.
- **IaC:** AWS CDK TypeScript.
- **Auth:** Amazon Cognito Phone OTP.
- **Map provider:** GOONG Map SDK/API.
- **Web search MVP:** Keyword/simple search trên MapVibe place data, chưa dùng Bedrock/KB.
- **Place resolver:** Hybrid resolver.
  - Ưu tiên MapVibe DB.
  - Fallback GOONG Places/Nearby/Autocomplete khi match yếu.
  - GOONG `place_id` chỉ là external reference, không là source of truth.
- **Nguồn dữ liệu public:** MapVibe DynamoDB.
- **Custom place:** Friends-visible mặc định, không public ngay.
- **Public toggle:** "Đề xuất công khai", tạo admin review candidate, không publish trực tiếp.
- **Giới hạn tạo custom place:** 5 địa điểm/người dùng/ngày.
- **Promotion:** Score + admin queue.
- **External social signals:** Không nằm trong MVP.
- **Bedrock AI search, AI summary, gamification:** Phase 2.
- **LocalStack:** Không dùng. Dev/test dùng AWS dev.
- **Budget:** PRD giữ ngân sách AWS <$200/8 tuần. GOONG Map/Places và SMS OTP theo quota/cost guardrail riêng.
- **Business rules:** Xem `docs/MapVibe_Business_Rules.md` để khóa MVP camera-first, rule place selection, mock JSON và scope guide cho design.

### 1.2 Non-goals của MVP

- Không build website người dùng.
- Không dùng Full GOONG Places API làm nguồn dữ liệu chính.
- Không tự động crawl TikTok/Instagram/Facebook/YouTube.
- Không auto-publish địa điểm public dựa trên số vote/comment.
- Không cho user nhập lat/lng thủ công để tạo địa điểm.
- Không để địa điểm custom searchable toàn hệ thống trước khi được duyệt.
- Không triển khai Bedrock natural-language search trong MVP.

---

## 2. Jira setup đề xuất

### 2.1 Issue types

- **Epic:** Nhóm năng lực sản phẩm/hạ tầng lớn.
- **Story:** Tính năng có giá trị trực tiếp cho user/admin.
- **Task:** Công việc kỹ thuật, infra, data model, CI/CD, guardrail.
- **Bug:** Lỗi phát sinh sau implementation.
- **Spike:** Nghiên cứu ngắn, có output rõ.

### 2.2 Optional labels

Jira issue không bắt buộc phải gắn component/folder. Dùng label chỉ khi giúp lọc backlog:

- `Mobile`: Flutter Android app, camera, map, UI flows.
- `Backend`: Lambda APIs, business logic, validation.
- `Infra`: CDK, API Gateway, WAF, CloudWatch, IAM, S3, CloudFront.
- `Data`: DynamoDB schema, indexes, seed, migrations.
- `Social`: friendship, feed, reactions, comments.
- `Moderation`: Rekognition, admin queue, audit log.
- `Admin`: internal admin web.
- `Cost`: AWS budgets, GOONG quota, SMS guardrails.

### 2.3 Priority

- **P0 / Highest:** MVP blocker, bảo mật/cost/data integrity quan trọng.
- **P1 / High:** Core user flow, cần có để demo/release.
- **P2 / Medium:** Nâng UX hoặc vận hành nhưng có thể release nếu thiếu.
- **P3 / Low:** Nice-to-have hoặc Phase 2.

### 2.4 Story point scale

- **1 SP:** Config nhỏ, copy/documentation, UI text.
- **2 SP:** Endpoint đơn giản, màn hình đơn giản, rule validation nhỏ.
- **3 SP:** Feature độc lập có DB/API/UI rõ.
- **5 SP:** Feature nhiều lớp: mobile + API + DB hoặc async worker.
- **8 SP:** Core capability nhiều rủi ro: resolver, promotion scoring, admin moderation.

### 2.5 Definition of Done

Một ticket chỉ được coi là Done khi:

- AC pass đầy đủ.
- Unit tests hoặc integration tests phù hợp scope đã có.
- Logs/metrics cơ bản được thêm cho flow quan trọng.
- Rate limit/permission/validation đã xử lý.
- Không tạo đường tắt bypass admin moderation.
- Không có LocalStack reference mới.
- Không hardcode secret/API key trong repo.
- Có cập nhật docs khi behavior/API đổi.

### 2.6 Backlog board hiển thị trong Jira

Backlog nên quản lý bằng Jira Scrum board, không chỉ bằng danh sách daily plan trong docs.

**Board columns:**

| Column | Ý nghĩa | Rule kéo ticket |
|---|---|---|
| `Backlog` | Việc chưa vào sprint hiện tại. | Chỉ chứa ticket chưa cần làm ngay hoặc can-slip. |
| `Selected for Sprint` | Việc đã commit cho sprint. | PM/lead kéo vào trước sprint planning. |
| `In Progress` | Đang code/design/test. | Assignee tự kéo khi bắt đầu làm trong ngày. |
| `Blocked` | Bị chặn bởi API/design/test data/quyết định scope. | Phải ghi blocker rõ trong comment. |
| `In Review` | Chờ review code/UI/contract. | Có PR, mock, screenshot, hoặc contract draft để review. |
| `QA / Evidence` | Đang smoke/integration/đính evidence. | Duy hoặc owner chạy test, attach pass/fail. |
| `Done` | Hoàn tất theo Definition of Done. | AC pass, test/evidence đủ, docs cập nhật nếu cần. |

**Quick filters nên có:**

- `Assignee = Minh`
- `Assignee = ty ty`
- `Assignee = Hân`
- `Assignee = Duy`
- `Label/Component = Mobile`
- `Label/Component = Backend`
- `Label/Component = Admin`
- `Label/Component = QA`
- `Priority = P0`
- `Blocked only`

**Swimlane khuyến nghị:**

- Dùng `Stories` để parent story nằm đầu swimlane, subtask nằm dưới.
- Khi daily standup, nhìn theo assignee filter trước, rồi mở swimlane parent để thấy flow có bị lệch hay không.
- Không quản lý bằng epic quá sớm trong daily vì team cần thấy task nhỏ theo ngày.

### 2.7 Cách chia task trong backlog

Task daily phải là subtask nhỏ, có owner rõ, output test được trong 0.5-2 ngày. Parent story giữ business capability; subtask là việc triển khai cụ thể.

| Parent | Capability | Subtasks dùng trong lịch daily |
|---|---|---|
| `MAP-13` | Camera capture, upload, media record | `MAP-31`, `MAP-32`, `MAP-33` |
| `MAP-14` | Nearby resolver sau khi chụp ảnh | `MAP-35`, `MAP-36`, `MAP-37`, `MAP-38`, `MAP-39` |
| `MAP-15` | Custom place + dedupe | `MAP-40`, `MAP-41`, `MAP-42`, `MAP-43` |
| `MAP-24` | Rekognition moderation pipeline | `MAP-44`, `MAP-45` |
| `MAP-25` | Admin review public request | `MAP-46`, `MAP-47`, `MAP-48`, `MAP-49` |
| `MAP-27` | Curated seed places | `MAP-50`, `MAP-51` |
| `MAP-28` | MVP test matrix/evidence | `MAP-52`, `MAP-53`, `MAP-54`, `MAP-55` |
| `MAP-29` | Internal release/runbook | `MAP-56`, `MAP-57` |
| `MAP-10` | Guardrails/quota/abuse | `MAP-59`, `MAP-60` |
| `MAP-16` | Saved places optional polish | `MAP-62` |

**Task split rules:**

- Backend API ticket phải có contract, validation, permission, tests/logging tối thiểu.
- Mobile ticket phải có happy path, loading/error state, mock/API adapter rõ.
- Admin UI ticket phải có list/detail/action state, nhưng không cần polish quá mức trước API stable.
- QA ticket phải ghi input case, expected result, pass/fail, bug list.
- Evidence ticket không được dùng để build feature mới; chỉ xác nhận feature đã xong.

### 2.8 Sprint setup

Daily plan chia thành 2 sprint ngắn để dễ quản lý scope và demo.

| Sprint | Dates | Goal | Main tickets |
|---|---|---|---|
| `MAP Sprint 2` | 2026-05-26 to 2026-06-02 | Camera-first foundation: upload, GPS proof, nearby resolver, custom place, seed, admin mock. | `MAP-31`, `MAP-32`, `MAP-33`, `MAP-35`, `MAP-36`, `MAP-37`, `MAP-38`, `MAP-39`, `MAP-40`, `MAP-41`, `MAP-42`, `MAP-43`, `MAP-44`, `MAP-45`, `MAP-46`, `MAP-47`, `MAP-50`, `MAP-51`, `MAP-52` |
| `MAP Sprint 3` | 2026-06-03 to 2026-06-06 | Integration hardening: admin review API, mobile/admin smoke evidence, guardrails, quota docs, release notes. | `MAP-48`, `MAP-49`, `MAP-52`, `MAP-53`, `MAP-54`, `MAP-55`, `MAP-56`, `MAP-57`, `MAP-59`, `MAP-60`, optional `MAP-62` |

**Sprint operating rules:**

- Sprint 2 ưu tiên feature build; Sprint 3 ưu tiên integration, QA, evidence, release readiness.
- Không kéo task mới vào Sprint 3 nếu critical path chưa xanh.
- `MAP-62` chỉ vào Sprint 3 nếu mobile smoke, admin smoke, backend tests đều pass.
- P0 bug trong critical path được phép thay thế optional/polish task.
- Cuối mỗi ngày update Jira status theo daily plan, không để ticket đang làm vẫn nằm `To Do`.

---

## 3. Data model nền tảng

### 3.1 Public entities

- `Place`
  - Địa điểm public, ai cũng search/discover được.
  - Chỉ tạo qua seed, admin approve, hoặc merge từ candidate.
  - Có thể lưu `goong_place_id` làm external reference.
- `PlaceCandidate`
  - Địa điểm user tạo hoặc GOONG gợi ý nhưng chưa public.
  - Visibility mặc định: `FRIENDS`.
  - Có owner, tọa độ, normalized name, evidence photos/check-ins.
- `PromotionCandidate`
  - Hồ sơ đề xuất public.
  - Tạo khi user bật "Đề xuất công khai" hoặc score đủ điều kiện.
  - Admin phải approve/merge/reject.
- `SavedPlace`
  - Quan hệ user lưu place/candidate vào danh sách cá nhân.
- `CheckInPost`
  - Ảnh/caption/check-in user đăng cho bạn bè.
- `Media`
  - File ảnh/video metadata, moderation status, S3 key, GPS proof, source (`IN_APP_CAMERA` hoặc `EXIF_GALLERY`) và owner user id.
- `Friendship`
  - Quan hệ mutual friends.
- `Comment`, `Vote`
  - Tương tác trên check-in post hoặc promotion candidate.
- `AuditLog`
  - Log hành động admin và các quyết định merge/reject.

### 3.2 Status đề xuất

- `Place.status`: `PUBLISHED`, `HIDDEN`, `MERGED`
- `PlaceCandidate.status`: `PRIVATE`, `FRIENDS_VISIBLE`, `PENDING_PUBLIC_REVIEW`, `APPROVED`, `REJECTED`, `MERGED`
- `PromotionCandidate.status`: `PENDING`, `APPROVED`, `REJECTED`, `MERGED`, `NEEDS_MORE_EVIDENCE`
- `Media.status`: `PENDING_MODERATION`, `APPROVED`, `REJECTED`
- `Friendship.status`: `PENDING`, `ACCEPTED`, `BLOCKED`

### 3.3 Business rules bắt buộc

- Custom place không thành `Place` public ngay.
- User tạo tối đa 5 custom places/ngày.
- Custom place phải có GPS capture từ app.
- Nếu tên normalized giống >=85% trong bán kính 100m, bắt user chọn/merge thay vì tạo mới.
- Nếu GOONG `place_id` đã map với `Place`/`PlaceCandidate`, không tạo duplicate.
- Friends-only post/list chỉ mutual friends thấy.
- User bật public chỉ tạo review queue, không public ngay.
- Promotion đủ score chỉ vào admin queue, không auto publish.
- Admin approve phải ghi `AuditLog`.
- Reject/merge phải có reason.

---

## 4. Product backlog chi tiết

## EPIC 1: Foundation, Infra & Cost Guardrails

**Mã Epic:** `MAP-EPIC-01`  
**Mục tiêu:** Tạo nền repo, CDK, AWS dev/prod, auth base, cost/security guardrails.  
**MVP Critical:** Có.

### [MAP-001] Setup Monorepo for Mobile, Backend, Admin, Infra

- **Issue Type:** Task
- **Priority:** P0
- **Story Points:** 3
- **Component:** `Infra`, `Mobile`, `Backend`
- **Blocked By:** None
- **Description:** Tạo cấu trúc repo chuẩn để phát triển Flutter app, Lambda backend, admin web tối thiểu, CDK infra và docs.
- **Acceptance Criteria:**
  - [ ] Repo có cấu trúc: `/apps/mobile`, `/apps/admin`, `/services/api`, `/infra/cdk`, `/docs`.
  - [ ] Flutter project được tạo cho Android.
  - [ ] Backend TypeScript Lambda project được tạo.
  - [ ] Admin web project tối thiểu được tạo.
  - [ ] CDK TypeScript app được tạo.
  - [ ] Cấu hình lint/format/test cơ bản cho từng workspace.
    - [ ] README ghi rõ không dùng LocalStack; dev/test dùng AWS dev.
- **Technical Notes:** Tránh tạo abstraction sớm. Ưu tiên cấu trúc dễ split ticket và deploy theo stage.

### [MAP-002] Provision AWS Dev/Prod with CDK TypeScript

- **Issue Type:** Task
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Infra`
- **Blocked By:** MAP-001
- **Description:** Thiết lập AWS CDK stacks cho dev/prod thay thế LocalStack.
- **Acceptance Criteria:**
  - [ ] CDK support stage: `dev`, `prod`; stage khác fail fast.
  - [ ] CDK tạo API Gateway, Lambda, DynamoDB, S3 media bucket, CloudFront media distribution, Cognito, WAF.
  - [ ] Tài nguyên non-prod có naming convention rõ: `mapvibe-{stage}-{resource}`.
  - [ ] Có script deploy/synth/diff: `cdk:synth`, `cdk:diff`, `cdk:deploy:dev`, `cdk:diff:prod`.
  - [ ] Non-prod có TTL/tagging để dễ cleanup cost.
  - [ ] Không có file compose LocalStack, local AWS app env, hoặc endpoint AWS emulator local.
- **Technical Notes:** Stack chính chạy `ap-southeast-1`; WAF CloudFront media chạy `us-east-1`. CDK phải dùng least-privilege IAM. Không wildcard IAM nếu không có lý do rõ.

### [MAP-003] Configure Cost, Quota, Security and Observability Guardrails

- **Issue Type:** Task
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Infra`, `Cost`
- **Blocked By:** MAP-002
- **Description:** Bảo vệ ngân sách AWS <$200/8 tuần và kiểm soát GOONG/SMS bằng quota riêng.
- **Acceptance Criteria:**
  - [ ] AWS Budgets có cảnh báo 50%, 75%, 90%, 100% forecast/actual.
  - [ ] CloudWatch alarms cho Lambda errors, API Gateway 5xx/4xx spike, DynamoDB throttles, S3 errors.
  - [ ] WAF rate limit cho API Gateway.
  - [ ] API rate limit theo user/IP/device cho OTP, upload, create candidate, vote/comment.
  - [ ] GOONG Map/Places quota documented trong docs và provider console.
  - [ ] Cognito SMS OTP rate limit và abuse policy documented.
  - [ ] Logs có correlation id/request id.
- **Technical Notes:** AWS budget không bao gồm GOONG/SMS theo quyết định hiện tại, nhưng docs phải tách rõ để tránh hiểu nhầm.

### [MAP-004] Implement Cognito Phone OTP Authentication and RBAC

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Backend`, `Mobile`, `Infra`
- **Blocked By:** MAP-002
- **Description:** Người dùng đăng nhập bằng số điện thoại. Admin/moderator có quyền riêng.
- **Acceptance Criteria:**
  - [ ] Cognito User Pool hỗ trợ phone number sign-in.
  - [ ] Mobile có màn hình nhập số điện thoại, nhập OTP, resend OTP.
  - [ ] API Gateway protected routes dùng Cognito JWT authorizer.
  - [ ] Cognito groups: `Users`, `Moderators`, `Admins`.
  - [ ] OTP resend có cooldown.
  - [ ] Quá số lần verify sai bị tạm khóa theo policy.
  - [ ] Backend nhận được `sub`, phone number và group claims trong request context.
- **Technical Notes:** Không tự lưu OTP. Không log OTP, phone full raw, token, refresh token.

---

## EPIC 2: Mobile Check-in, Camera & Nearby Place Scan

**Mã Epic:** `MAP-EPIC-02`  
**Mục tiêu:** Build luồng mobile giống UI mẫu: scan quanh vị trí, chọn gợi ý, hoặc tạo custom place.  
**MVP Critical:** Có.

### [MAP-005] Build Flutter Android App Shell with GOONG Map

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Mobile`
- **Blocked By:** MAP-001, MAP-004
- **Description:** Tạo app shell Flutter Android với auth state, map home, location permission và button camera/check-in.
- **Acceptance Criteria:**
  - [ ] App chạy trên Android emulator/device.
  - [ ] User chưa login thấy auth flow.
  - [ ] User login thấy map home.
  - [ ] App xin quyền location runtime.
  - [ ] Map hiển thị current location.
  - [ ] Có camera/check-in CTA.
  - [ ] GOONG Map API key không hardcode trong source public.
- **Technical Notes:** Nếu user deny location, show fallback UX rõ và không cho tạo place từ tọa độ giả.

### [MAP-006] Implement In-App Camera Capture with GPS Proof and S3 Upload

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Mobile`, `Backend`, `Infra`
- **Blocked By:** MAP-005
- **Description:** User chụp ảnh trong app, ảnh gắn GPS proof, upload qua S3 presigned URL.
- **Acceptance Criteria:**
  - [ ] Mobile mở camera trong app.
  - [ ] Khi chụp, app capture current GPS, timestamp, accuracy.
  - [ ] Backend cấp `POST /media/uploads` chỉ cho authenticated user và trả presigned S3 POST.
  - [ ] File type chỉ cho phép `image/jpeg`, `image/png`, `image/webp`.
  - [ ] File size giới hạn tối đa 5MB cho MVP.
  - [ ] Presigned POST ràng buộc đúng S3 key, `Content-Type`, signed metadata và `content-length-range` 1-5MB.
  - [ ] Free user + `EXIF_GALLERY` bị chặn `403`; Free user + `IN_APP_CAMERA` được phép.
  - [ ] Pro user được phép dùng cả `EXIF_GALLERY` và `IN_APP_CAMERA`.
  - [ ] Upload thành công tạo `Media` status `PENDING_MODERATION` qua pipeline S3 EventBridge -> EventBridge rule -> SQS + DLQ -> worker Lambda.
  - [ ] Worker đọc `HeadObject`, revalidate metadata/object, và ghi `Media` idempotent theo `mediaId`.
  - [ ] `UserProfilesTable` là source of truth cho Free/Pro; thiếu profile mặc định là Free.
  - [ ] Nếu location accuracy kém hơn ngưỡng cấu hình, app yêu cầu retry/confirm.
- **Technical Notes:** Không proxy ảnh qua Lambda/API Gateway. Image bytes đi thẳng mobile -> S3; Lambda chỉ cấp presigned POST và xử lý metadata/event.

### [MAP-007] Implement Nearby Place Scan and Hybrid Resolver API

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 8
- **Component:** `Backend`, `Data`, `Mobile`
- **Blocked By:** MAP-005, MAP-006
- **Description:** Sau khi user chụp ảnh, scan khu vực quanh GPS proof của ảnh và trả gợi ý địa điểm: MapVibe DB trước, GOONG fallback sau.
- **Acceptance Criteria:**
  - [ ] API `GET /places/nearby?lat={lat}&lng={lng}&radius={meters}&context=camera_check_in&media_id={media_id}`.
  - [ ] Radius mặc định 100m, max 300m cho MVP.
  - [ ] Kết quả gồm public `Place`, friends-visible `PlaceCandidate`, và GOONG fallback nếu cần.
  - [ ] Ranking ưu tiên: exact DB match, friend candidate, high-confidence GOONG match, low-confidence GOONG match.
  - [ ] Mỗi result có `source`, `confidence`, `distance_meters`, `display_name`, `category`, `address`.
  - [ ] Mobile gọi API sau khi chụp ảnh và hiển thị bottom sheet danh sách quán gần ảnh vừa chụp.
  - [ ] User có thể search/filter trong danh sách gần đó.
  - [ ] Có CTA `Tạo địa điểm tùy chỉnh` khi không thấy match đúng.
  - [ ] Map-first place selection không nằm trong scope MVP của ticket này.
- **Technical Notes:** GOONG Places fallback phải dùng quota guardrail. Không lưu toàn bộ payload GOONG nếu không cần. Chỉ lưu field tối thiểu phục vụ dedupe/reference.

### [MAP-008] Implement Custom Place Candidate Creation with Deduplication

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 8
- **Component:** `Backend`, `Data`, `Mobile`
- **Blocked By:** MAP-007
- **Description:** User tạo địa điểm tùy chỉnh nhưng không tạo public place vô tội vạ.
- **Acceptance Criteria:**
  - [ ] API `POST /place-candidates`.
  - [ ] Payload bắt buộc: name, lat, lng, source media/check-in id, visibility.
  - [ ] Không nhận lat/lng nhập tay từ form; tọa độ phải từ GPS captured session.
  - [ ] Name được normalize: lowercase, trim, bỏ dấu, bỏ ký tự nhiễu.
  - [ ] Trước khi tạo, backend kiểm tra duplicate trong bán kính 100m.
  - [ ] Nếu name similarity >=85% với place/candidate hiện có, trả về conflict candidates để user chọn.
  - [ ] Nếu GOONG `place_id` trùng bản ghi đã có, không tạo mới.
  - [ ] User bị giới hạn 5 custom places/ngày.
  - [ ] Candidate mới mặc định status `FRIENDS_VISIBLE`.
  - [ ] Candidate không xuất hiện trong public search/discover.
- **Technical Notes:** Dedupe phải chạy server-side. Mobile chỉ hỗ trợ UX, không là lớp bảo vệ chính.

### [MAP-009] Implement Add to My Map / Saved Food List

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Mobile`, `Backend`, `Data`
- **Blocked By:** MAP-007, MAP-008
- **Description:** User lưu place/candidate vào bản đồ cá nhân hoặc danh sách quán của mình.
- **Acceptance Criteria:**
  - [ ] API `POST /saved-places`.
  - [ ] User lưu được `Place` public hoặc `PlaceCandidate` friends-visible.
  - [ ] Không tạo duplicate saved item cho cùng user/place.
  - [ ] Mobile có CTA "Thêm vào bản đồ của tôi".
  - [ ] Saved list hiển thị tên, ảnh, category, last check-in, visibility.
  - [ ] Friends chỉ xem được saved item có visibility hợp lệ.
- **Technical Notes:** Saved list là social object riêng, không đồng nghĩa public place.

---

## EPIC 3: Social Graph, Feed & Interactions

**Mã Epic:** `MAP-EPIC-03`  
**Mục tiêu:** Tạo vòng bạn bè mutual và feed friends-only.  
**MVP Critical:** Có.

### [MAP-010] Implement Mutual Friends

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Social`, `Backend`, `Mobile`
- **Blocked By:** MAP-004
- **Description:** Người dùng kết bạn hai chiều để xem list/feed của nhau.
- **Acceptance Criteria:**
  - [ ] API gửi lời mời kết bạn bằng phone number hoặc user id.
  - [ ] API accept/reject/cancel request.
  - [ ] Friendship chỉ active khi cả hai bên accept.
  - [ ] Mobile có danh sách bạn bè và pending requests.
  - [ ] Block user ngăn xem feed/list và ngăn gửi request mới.
  - [ ] Backend enforce permission cho mọi endpoint friends-only.
- **Technical Notes:** Không expose phone number người khác nếu chưa là bạn hoặc chưa consent.

### [MAP-011] Implement Friends-Only Check-in Posts

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Social`, `Mobile`, `Backend`
- **Blocked By:** MAP-006, MAP-009, MAP-010
- **Description:** User đăng ảnh/check-in gắn place/candidate cho vòng bạn bè.
- **Acceptance Criteria:**
  - [ ] API `POST /check-ins`.
  - [ ] Check-in bắt buộc gắn media đã upload và place/candidate hợp lệ.
  - [ ] Default visibility `FRIENDS`.
  - [ ] Friend feed chỉ trả post từ mutual friends.
  - [ ] Owner có thể xóa post của mình.
  - [ ] Xóa post không xóa place/candidate nếu đã có saved item hoặc promotion candidate liên quan.
  - [ ] Mobile hiển thị feed cơ bản: ảnh, tên quán, người đăng, thời gian, comment/upvote count.
- **Technical Notes:** Feed MVP có thể dùng query theo friendship + pagination đơn giản. Không cần recommendation ML.

### [MAP-012] Implement Comments and Upvotes with Anti-Spam Rules

- **Issue Type:** Story
- **Priority:** P1
- **Story Points:** 5
- **Component:** `Social`, `Backend`, `Data`
- **Blocked By:** MAP-011
- **Description:** Bạn bè tương tác với check-in post bằng comment/upvote.
- **Acceptance Criteria:**
  - [ ] API upvote/unupvote post.
  - [ ] API create/delete comment.
  - [ ] Mỗi user chỉ có 1 active upvote/post.
  - [ ] Comment chỉ cho mutual friends và owner.
  - [ ] Rate limit theo user/device/IP.
  - [ ] Comment duplicate/spam bị reject theo rule MVP.
  - [ ] Deleted comment không tính vào promotion score.
  - [ ] Audit metric cho vote/comment spike.
- **Technical Notes:** Upvote/comment là social signal, không phải public rating/review.

---

## EPIC 4: Promotion, Discover & Public Place Governance

**Mã Epic:** `MAP-EPIC-04`  
**Mục tiêu:** Biến social signals thành candidate duyệt public, tránh tạo data rác.  
**MVP Critical:** Có.

### [MAP-013] Implement Promotion Candidate and Public Opt-in Flow

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Backend`, `Mobile`, `Data`
- **Blocked By:** MAP-011, MAP-012
- **Description:** Khi user muốn đưa địa điểm lên công khai, hệ thống tạo promotion candidate thay vì public ngay.
- **Acceptance Criteria:**
  - [ ] Mobile đổi label toggle thành "Đề xuất công khai".
  - [ ] API `POST /promotion-candidates`.
  - [ ] Promotion candidate yêu cầu place/candidate, owner, evidence media/check-in.
  - [ ] Candidate status mặc định `PENDING`.
  - [ ] Nếu duplicate promotion đang pending cho cùng place/candidate, backend merge evidence thay vì tạo mới.
  - [ ] User thấy trạng thái: pending, approved, rejected, needs more evidence.
  - [ ] Public search không hiển thị pending candidate.
- **Technical Notes:** Đây là lớp bảo vệ data quality quan trọng nhất.

### [MAP-014] Implement Promotion Score Engine

- **Issue Type:** Task
- **Priority:** P1
- **Story Points:** 8
- **Component:** `Backend`, `Data`, `Moderation`
- **Blocked By:** MAP-012, MAP-013
- **Description:** Tính score chống spam để ưu tiên queue admin.
- **Acceptance Criteria:**
  - [ ] Score dựa trên unique check-ins, unique saves, unique upvotes, unique commenters, account trust, abuse penalty.
  - [ ] Account mới <7 ngày có weight thấp.
  - [ ] Một user không đóng góp quá 20% tổng score.
  - [ ] Một friend cluster không đóng góp quá 60% tổng score.
  - [ ] Cần tối thiểu 3 photo check-ins gần nhau trong 100m để high priority.
  - [ ] Score đủ ngưỡng chỉ tăng priority queue, không auto publish.
  - [ ] Admin UI thấy lý do score và evidence chính.
- **Technical Notes:** MVP có thể chạy score khi interaction event xảy ra. Nightly batch tối ưu để Phase 2.

### [MAP-015] Implement Discover Feed from Approved/Public and Pending Candidates

- **Issue Type:** Story
- **Priority:** P1
- **Story Points:** 5
- **Component:** `Mobile`, `Backend`, `Data`
- **Blocked By:** MAP-013, MAP-014
- **Description:** Discover hiển thị nội dung public/đủ điều kiện theo signal nội bộ, không dùng external social crawling.
- **Acceptance Criteria:**
  - [ ] API `GET /discover`.
  - [ ] Feed public chỉ hiển thị `Place` approved hoặc promotion content được phép hiển thị.
  - [ ] Pending candidate chỉ hiển thị nếu owner đã opt-in và policy cho phép teaser friends/public.
  - [ ] Không hiển thị friends-only post chưa opt-in.
  - [ ] Ranking dùng internal score, recency, media quality, moderation status.
  - [ ] Mobile có list/card discover cơ bản.
- **Technical Notes:** Nếu privacy chưa chắc, MVP nên chỉ hiện approved public places trong Discover; pending chỉ nằm ở admin queue.

### [MAP-016] Implement Public Place Profile, Basic Search and Rating

- **Issue Type:** Story
- **Priority:** P1
- **Story Points:** 5
- **Component:** `Mobile`, `Backend`, `Data`
- **Blocked By:** MAP-015
- **Description:** Địa điểm đã approved có profile public, search cơ bản, rating/review tách khỏi comment social.
- **Acceptance Criteria:**
  - [ ] API `GET /places/{id}`.
  - [ ] API `GET /places/search?q=&lat=&lng=`.
  - [ ] API `POST /places/{id}/reviews`.
  - [ ] Chỉ `Place.status=PUBLISHED` mới search public được.
  - [ ] Review/rating chỉ áp dụng cho public Place.
  - [ ] Một user có tối đa 1 active review/public place.
  - [ ] Rating gồm overall hoặc food/price/service nếu kịp scope.
  - [ ] Comment trên check-in không tự convert thành review.
- **Technical Notes:** Giữ review model đơn giản. AI summary để Phase 2.

---

## EPIC 5: Moderation, Admin Web & Audit

**Mã Epic:** `MAP-EPIC-05`  
**Mục tiêu:** Admin kiểm soát data public, media safety, merge duplicate.  
**MVP Critical:** Có.

### [MAP-017] Implement Image Moderation Pipeline with Rekognition

- **Issue Type:** Task
- **Priority:** P0
- **Story Points:** 5
- **Component:** `Moderation`, `Infra`, `Backend`
- **Blocked By:** MAP-006
- **Description:** Ảnh user upload phải được moderation trước khi dùng rộng.
- **Acceptance Criteria:**
  - [ ] S3 event trigger Lambda moderation.
  - [ ] Lambda gọi Rekognition `DetectModerationLabels`.
  - [ ] Safe image chuyển `Media.status=APPROVED`.
  - [ ] Unsafe image chuyển `Media.status=REJECTED`.
  - [ ] Rejected media không hiển thị trong feed/discover.
  - [ ] Moderation result lưu labels/confidence tối thiểu phục vụ audit.
  - [ ] Error/retry có DLQ hoặc retry policy rõ.
- **Technical Notes:** Không block mobile upload UX bằng Rekognition synchronous call. UI hiển thị pending state.

### [MAP-018] Build Minimal Admin Web for Promotion Review

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 8
- **Component:** `Admin`, `Backend`, `Moderation`
- **Blocked By:** MAP-013, MAP-017
- **Description:** Admin/moderator duyệt candidate lên public, merge duplicate, reject rác.
- **Acceptance Criteria:**
  - [ ] Admin web chỉ cho `Moderators`/`Admins`.
  - [ ] List pending promotion candidates có search/filter/sort by score.
  - [ ] Detail view hiển thị: name, map pin, evidence photos, creator, score reasons, duplicate candidates.
  - [ ] Admin action: approve as new public Place.
  - [ ] Admin action: merge into existing Place.
  - [ ] Admin action: reject with reason.
  - [ ] Mọi action ghi `AuditLog`.
  - [ ] Mobile/user thấy status sau khi admin xử lý.
- **Technical Notes:** Admin web tối thiểu, không cần polish như consumer app. Ưu tiên correctness.

### [MAP-019] Implement Place Merge and Duplicate Management

- **Issue Type:** Task
- **Priority:** P1
- **Story Points:** 5
- **Component:** `Data`, `Backend`, `Admin`
- **Blocked By:** MAP-018
- **Description:** Cho phép gộp candidate hoặc duplicate place để giữ DB sạch.
- **Acceptance Criteria:**
  - [ ] Merge candidate vào existing Place.
  - [ ] SavedPlace/check-in/promotion references được cập nhật hoặc resolve qua redirect.
  - [ ] Merged candidate giữ audit trail.
  - [ ] API không trả duplicate đã merge trong nearby scan.
  - [ ] Admin bắt buộc nhập reason khi merge.
- **Technical Notes:** Tránh hard delete. Dùng `MERGED` + `merged_into_id`.

---

## EPIC 6: Seed Data, QA & Release Readiness

**Mã Epic:** `MAP-EPIC-06`  
**Mục tiêu:** Chuẩn bị data ban đầu, test, release Android internal.  
**MVP Critical:** Có.

### [MAP-020] Prepare Curated Seed Places for Initial City Area

- **Issue Type:** Task
- **Priority:** P1
- **Story Points:** 3
- **Component:** `Data`
- **Blocked By:** MAP-002
- **Description:** Seed 50-200 địa điểm ăn uống ban đầu để nearby scan có dữ liệu thật.
- **Acceptance Criteria:**
  - [ ] Seed file có name, normalized name, category, lat/lng, address, source note.
  - [ ] Seed import idempotent.
  - [ ] Có ít nhất một khu vực test dày đủ để scan UI hiển thị nhiều lựa chọn.
  - [ ] Không import dữ liệu vi phạm license.
  - [ ] GOONG `place_id` chỉ thêm khi được resolve hợp lệ.
- **Technical Notes:** Curated seed giúp UX tốt mà không phụ thuộc Full GOONG Places API.

### [MAP-021] Implement MVP Test Matrix and Critical Integration Tests

- **Issue Type:** Task
- **Priority:** P1
- **Story Points:** 5
- **Component:** `Backend`, `Mobile`, `Infra`
- **Blocked By:** MAP-004, MAP-007, MAP-018
- **Description:** Kiểm thử các luồng critical trước demo/release.
- **Acceptance Criteria:**
  - [ ] Test auth OTP happy path và blocked path.
  - [ ] Test nearby resolver DB match, GOONG fallback, no match.
  - [ ] Test duplicate custom place conflict.
  - [ ] Test friends-only permission.
  - [ ] Test promotion candidate approve/merge/reject.
  - [ ] Test public search chỉ trả approved Place.
  - [ ] Test rate limit cho create custom place và OTP.
  - [ ] Mobile smoke test trên Android device/emulator.
- **Technical Notes:** Integration tests chạy trên AWS dev, không LocalStack.

### [MAP-022] Android Internal Release and Operational Runbook

- **Issue Type:** Task
- **Priority:** P1
- **Story Points:** 3
- **Component:** `Mobile`, `Infra`, `Cost`
- **Blocked By:** MAP-021
- **Description:** Chuẩn bị bản Android internal release và runbook vận hành MVP.
- **Acceptance Criteria:**
  - [ ] Build Android release/internal APK hoặc app bundle.
  - [ ] Env/config prod-like được tách khỏi dev.
  - [ ] Runbook có cách kiểm tra alarms, logs, failed media moderation, pending queue.
  - [ ] Runbook có cách tạm khóa GOONG fallback nếu cost spike.
  - [ ] Runbook có cách disable promotion submission nếu spam.
  - [ ] Known limitations MVP được ghi rõ.
- **Technical Notes:** Release trước tiên là internal/testing release, chưa cần public store nếu chưa chốt store policy.

---

## 5. Phase 2 Backlog

Các ticket sau không thuộc MVP 1 tháng, nhưng nên giữ trong roadmap.

### [MAP-P2-001] Bedrock Natural Language Search

- Tìm quán bằng prompt tiếng Việt.
- Chỉ search trên public approved Places.
- Có cache 24h, prompt sanitation, cost alarms.

### [MAP-P2-002] AI Place Summary

- Tóm tắt review/check-in public bằng Bedrock.
- Refresh theo rule 7 ngày hoặc đủ review mới.

### [MAP-P2-003] Gamification Badge Engine

- Bronze/Silver/Gold theo số check-in/review hợp lệ.
- Chống farm bằng trust score.

### [MAP-P2-004] External Social Evidence

- Cho admin/user thêm link TikTok/Instagram/YouTube.
- Chỉ làm evidence phụ, không auto crawl MVP.

### [MAP-P2-005] iOS Release

- Build Flutter iOS.
- Xử lý Apple Sign-in nếu cần.
- QA permission/camera/location trên iOS.

### [MAP-P2-006] Advanced Place Recommendation

- Recommendation theo friend graph, saved places, categories, recency.
- Không cần ML trong v1.

---

## 6. MVP daily delivery schedule

Lịch này bám scope đã chốt ngày 2026-05-26: web app vẫn theo hướng AI search nhưng MVP chỉ keyword/simple search; mobile MVP là camera-first social food discovery; map/place provider là GOONG; user chỉ gửi yêu cầu public, admin duyệt trước khi địa điểm xuất hiện public.

### Ngày 27/5

**Minh:**
- MAP-35 Nearby API contract/mock.
- MAP-31 Upload API and Media record bắt đầu.

**ty ty:**
- MAP-32 Mobile camera capture and GPS proof.

**Hân:**
- MAP-46 Admin pending list mock UI.

**Duy:**
- MAP-50 Seed file bắt đầu.
- MAP-52 Test matrix skeleton.

### Ngày 28/5

**Minh:**
- MAP-31 Upload API and Media record hoàn tất.
- Nếu còn thời gian: chuẩn bị MAP-36.

**ty ty:**
- MAP-32 hoàn tất.
- Bắt đầu nối preview/upload với mock hoặc API thật.

**Hân:**
- MAP-33 Upload preview and pending status UI.
- Tiếp tục MAP-46 nếu chưa xong.

**Duy:**
- MAP-50 hoàn tất 50-100 places.
- Bắt đầu MAP-51 seed import/verify.

### Ngày 29/5

**Minh:**
- MAP-36 Nearby API implementation.

**ty ty:**
- MAP-37 Mobile nearby bottom sheet.

**Hân:**
- MAP-38 Nearby UI polish.
- Nếu rảnh: tiếp MAP-47 admin detail/actions UI mock.

**Duy:**
- MAP-51 Seed import/verify.
- MAP-39 Nearby seed verification QA.

### Ngày 30/5

**Minh:**
- MAP-36 hoàn tất + tests.
- Chuẩn bị MAP-40.

**ty ty:**
- MAP-37 hoàn tất search/filter/select place.

**Hân:**
- MAP-38 hoàn tất.
- MAP-47 detail/actions UI mock bắt đầu.

**Duy:**
- MAP-39 hoàn tất.
- Update MAP-52 test matrix với nearby cases.

### Ngày 31/5

**Minh:**
- MAP-40 Custom place API + dedupe bắt đầu.

**ty ty:**
- MAP-41 Mobile custom place form bắt đầu.

**Hân:**
- MAP-42 Custom place conflict UI.
- Tiếp MAP-47 nếu chưa xong.

**Duy:**
- MAP-43 Duplicate QA cases chuẩn bị bằng mock/expected cases.

### Ngày 1/6

**Minh:**
- MAP-40 hoàn tất + tests.

**ty ty:**
- MAP-41 hoàn tất nối mock/real API.

**Hân:**
- MAP-42 hoàn tất.
- MAP-47 hoàn tất admin detail/actions UI mock.

**Duy:**
- MAP-43 chạy QA nếu API đã có.
- Update MAP-52.

### Ngày 2/6

**Minh:**
- MAP-44 Rekognition moderation pipeline.

**ty ty:**
- Mobile status UI pending/approved/rejected trong flow upload/custom place.
- Chuẩn bị evidence cho MAP-54.

**Hân:**
- MAP-46 + MAP-47 connect mock adapter sạch.
- Chuẩn bị connect API thật.

**Duy:**
- MAP-45 Moderation QA chuẩn bị cases.
- Tiếp MAP-52.

### Ngày 3/6

**Minh:**
- MAP-48 Admin review APIs.
- Fix contract mismatch cho MAP-31/36/40/44.

**ty ty:**
- Full mobile flow test lần 1.
- MAP-54 Mobile smoke evidence bắt đầu.

**Hân:**
- Connect Admin UI với MAP-48.
- MAP-55 Admin smoke evidence bắt đầu.

**Duy:**
- MAP-49 Admin QA.
- MAP-45 Moderation QA nếu pipeline ready.

### Ngày 4/6

**Minh:**
- Integration fix toàn bộ critical path.
- Nếu ổn mới làm MAP-59 guardrails.

**ty ty:**
- Finish MAP-54.
- P0 mobile fixes.

**Hân:**
- Finish MAP-55.
- Admin UI bugfix only.

**Duy:**
- Finish MAP-52 test matrix pass/fail lần 1.
- Gộp bug list P0/P1.

### Ngày 5/6

**Minh:**
- MAP-59 Guardrails implementation.
- MAP-53 Backend test evidence.

**ty ty:**
- Mobile smoke again.
- Optional MAP-62 chỉ làm nếu mọi critical path xanh.

**Hân:**
- Admin visual polish.
- Không thêm feature mới.

**Duy:**
- MAP-60 Quota/abuse docs.
- MAP-56 Runbook/demo script bắt đầu.

### Ngày 6/6

**Minh:**
- Backend tests/build/synth.
- MAP-53 hoàn tất.
- P0 fixes.

**ty ty:**
- Android analyze/test/smoke.
- MAP-57 Android build notes/artifact bắt đầu.

**Hân:**
- Admin regression.
- P0/P1 UI fixes.

**Duy:**
- MAP-52 final bug list.

---

## 7. Summary statistics

| Epic | P0 | P1 | P2 | Tickets | Story Points |
|---|---:|---:|---:|---:|---:|
| MAP-EPIC-01 Foundation, Infra & Cost | 4 | 0 | 0 | 4 | 18 |
| MAP-EPIC-02 Mobile Check-in & Scan | 5 | 0 | 0 | 5 | 31 |
| MAP-EPIC-03 Social Graph & Feed | 2 | 1 | 0 | 3 | 15 |
| MAP-EPIC-04 Promotion & Discover | 1 | 3 | 0 | 4 | 23 |
| MAP-EPIC-05 Moderation & Admin | 2 | 1 | 0 | 3 | 18 |
| MAP-EPIC-06 Seed, QA & Release | 0 | 3 | 0 | 3 | 11 |
| **Total MVP** | **14** | **8** | **0** | **22** | **116** |

### Delivery note

116 SP là scope đầy đủ để backlog không thiếu việc. Với mục tiêu demo MVP trong 1 tháng, team cần cắt release theo "must-demo" nếu capacity thấp:

- **Must-demo:** auth/dev deploy, GOONG app shell, camera + GPS proof + upload draft, nearby resolver contract/API, nearby sheet, custom candidate + dedupe, friends-only feed, public request, admin approve/reject basic, keyword public search, smoke tests, Android internal build.
- **Can slip 1-2 tuần:** promotion score nâng cao, discover ranking đẹp, rating đầy đủ, merge duplicate nâng cao, store-ready polish, Bedrock/KB AI search, map-first flow.

---

## 8. Rủi ro chính và mitigation

### 8.1 Tạo địa điểm rác

- **Risk:** User spam custom place.
- **Mitigation:** 5/ngày/user, GPS proof, duplicate check 100m, admin approve trước public, trust score.

### 8.2 Duplicate địa điểm

- **Risk:** Nhiều user tạo cùng quán với tên khác nhau.
- **Mitigation:** normalized name, similarity >=85%, GOONG `place_id`, merge workflow, no hard delete.

### 8.3 GOONG Places cost spike

- **Risk:** Nearby/Autocomplete fallback bị spam.
- **Mitigation:** DB-first resolver, quota, caching minimal, per-user/IP limits, kill switch fallback.

### 8.4 SMS OTP abuse

- **Risk:** Spam OTP gây tốn tiền.
- **Mitigation:** cooldown, per-phone/per-IP/per-device limits, Cognito protection, monitoring.

### 8.5 Privacy leak

- **Risk:** Friends-only check-in bị public nhầm.
- **Mitigation:** backend permission checks, explicit opt-in for public proposal, tests cho non-friend access.

### 8.6 Moderation backlog

- **Risk:** Admin queue quá nhiều candidate.
- **Mitigation:** score priority, duplicate auto-merge evidence, reject reason templates, bulk filters.

---

## 9. Acceptance criteria tổng MVP

MVP được coi là hoàn thành khi:

- User Android đăng nhập bằng phone OTP.
- User chụp ảnh trong app tại quán, upload ảnh, có GPS proof.
- App scan quanh vị trí và gợi ý địa điểm gần đó.
- User chọn địa điểm có sẵn hoặc tạo custom place friends-visible.
- User lưu địa điểm vào bản đồ/danh sách cá nhân.
- Mutual friends xem được feed/list; người ngoài không xem được.
- Bạn bè comment/upvote được.
- User đề xuất địa điểm công khai được.
- Admin duyệt/merge/reject được.
- Chỉ approved public places mới xuất hiện trong public search/discover.
- Ảnh được moderation trước khi hiển thị rộng.
- Không còn LocalStack scope trong backlog MVP.
- Có cost/rate-limit guardrails cho AWS, GOONG fallback và SMS OTP.

