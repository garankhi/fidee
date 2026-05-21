# MapVibe - Social Discovery MVP Backlog v2

## 1. Tổng quan

MapVibe MVP v1 là ứng dụng mobile social discovery cho ăn uống. Người dùng mở app tại quán, chụp ảnh bằng camera trong app, scan khu vực xung quanh để chọn địa điểm có sẵn hoặc tạo địa điểm tùy chỉnh, rồi lưu vào bản đồ/danh sách quán của mình để bạn bè xem.

Khác backlog cũ, MVP này không lấy AI search làm lõi. Lõi sản phẩm là vòng lặp:

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
- **Map provider:** Google Maps SDK.
- **Place resolver:** Hybrid resolver.
  - Ưu tiên MapVibe DB.
  - Fallback Google Places Nearby/Autocomplete khi match yếu.
  - Google `place_id` chỉ là external reference, không là source of truth.
- **Nguồn dữ liệu public:** MapVibe DynamoDB.
- **Custom place:** Friends-visible mặc định, không public ngay.
- **Public toggle:** "Đề xuất công khai", tạo admin review candidate, không publish trực tiếp.
- **Giới hạn tạo custom place:** 5 địa điểm/người dùng/ngày.
- **Promotion:** Score + admin queue.
- **External social signals:** Không nằm trong MVP.
- **AI search, AI summary, gamification:** Phase 2.
- **LocalStack:** Không dùng. Dev/test dùng AWS dev.
- **Budget:** PRD giữ ngân sách AWS <$200/8 tuần. Google Maps/Places và SMS OTP theo quota/cost guardrail riêng.

### 1.2 Non-goals của MVP

- Không build website người dùng.
- Không dùng Full Places API làm nguồn dữ liệu chính.
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
- `Cost`: AWS budgets, Google quota, SMS guardrails.

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

---

## 3. Data model nền tảng

### 3.1 Public entities

- `Place`
  - Địa điểm public, ai cũng search/discover được.
  - Chỉ tạo qua seed, admin approve, hoặc merge từ candidate.
  - Có thể lưu `google_place_id` làm external reference.
- `PlaceCandidate`
  - Địa điểm user tạo hoặc Google gợi ý nhưng chưa public.
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
  - File ảnh/video metadata, moderation status, S3 key, GPS proof.
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
- Nếu Google `place_id` đã map với `Place`/`PlaceCandidate`, không tạo duplicate.
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
- **Description:** Bảo vệ ngân sách AWS <$200/8 tuần và kiểm soát Google/SMS bằng quota riêng.
- **Acceptance Criteria:**
  - [ ] AWS Budgets có cảnh báo 50%, 75%, 90%, 100% forecast/actual.
  - [ ] CloudWatch alarms cho Lambda errors, API Gateway 5xx/4xx spike, DynamoDB throttles, S3 errors.
  - [ ] WAF rate limit cho API Gateway.
  - [ ] API rate limit theo user/IP/device cho OTP, upload, create candidate, vote/comment.
  - [ ] Google Maps/Places quota documented trong docs và cloud console.
  - [ ] Cognito SMS OTP rate limit và abuse policy documented.
  - [ ] Logs có correlation id/request id.
- **Technical Notes:** AWS budget không bao gồm Google/SMS theo quyết định hiện tại, nhưng docs phải tách rõ để tránh hiểu nhầm.

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

### [MAP-005] Build Flutter Android App Shell with Google Map

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
  - [ ] Google Maps API key không hardcode trong source public.
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
  - [ ] Backend cấp presigned upload URL chỉ cho authenticated user.
  - [ ] File type chỉ cho phép `image/jpeg`, `image/png`, `image/webp`.
  - [ ] File size giới hạn tối đa 5MB cho MVP.
  - [ ] Upload thành công tạo `Media` status `PENDING_MODERATION`.
  - [ ] Nếu location accuracy kém hơn ngưỡng cấu hình, app yêu cầu retry/confirm.
- **Technical Notes:** Không proxy ảnh qua Lambda/API Gateway.

### [MAP-007] Implement Nearby Place Scan and Hybrid Resolver API

- **Issue Type:** Story
- **Priority:** P0
- **Story Points:** 8
- **Component:** `Backend`, `Data`, `Mobile`
- **Blocked By:** MAP-005, MAP-006
- **Description:** Scan khu vực quanh user và trả gợi ý địa điểm: MapVibe DB trước, Google fallback sau.
- **Acceptance Criteria:**
  - [ ] API `GET /places/nearby?lat={lat}&lng={lng}&radius={meters}`.
  - [ ] Radius mặc định 100m, max 300m cho MVP.
  - [ ] Kết quả gồm public `Place`, friends-visible `PlaceCandidate`, và Google fallback nếu cần.
  - [ ] Ranking ưu tiên: exact DB match, friend candidate, high-confidence Google match, low-confidence Google match.
  - [ ] Mỗi result có `source`, `confidence`, `distance_meters`, `display_name`, `category`, `address`.
  - [ ] Mobile hiển thị bottom sheet danh sách quán gần đây giống UI mẫu.
  - [ ] User có thể search/filter trong danh sách gần đó.
  - [ ] Có CTA `Tạo địa điểm tùy chỉnh` khi không thấy match đúng.
- **Technical Notes:** Google Places fallback phải dùng quota guardrail. Không lưu toàn bộ payload Google nếu không cần. Chỉ lưu field tối thiểu phục vụ dedupe/reference.

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
  - [ ] Nếu Google `place_id` trùng bản ghi đã có, không tạo mới.
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
  - [ ] Google `place_id` chỉ thêm khi được resolve hợp lệ.
- **Technical Notes:** Curated seed giúp UX tốt mà không phụ thuộc Full Places API.

### [MAP-021] Implement MVP Test Matrix and Critical Integration Tests

- **Issue Type:** Task
- **Priority:** P1
- **Story Points:** 5
- **Component:** `Backend`, `Mobile`, `Infra`
- **Blocked By:** MAP-004, MAP-007, MAP-018
- **Description:** Kiểm thử các luồng critical trước demo/release.
- **Acceptance Criteria:**
  - [ ] Test auth OTP happy path và blocked path.
  - [ ] Test nearby resolver DB match, Google fallback, no match.
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
  - [ ] Runbook có cách tạm khóa Google fallback nếu cost spike.
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

## 6. Sprint plan 1 tháng

### Week 1: Foundation & Auth

- MAP-001 Setup Monorepo
- MAP-002 AWS Dev/Staging CDK
- MAP-003 Cost/Security Guardrails
- MAP-004 Cognito Phone OTP
- MAP-020 Seed Places bắt đầu song song

**Exit Criteria:**
- App Android login được.
- Backend deploy dev được.
- CDK deploy dev được.
- Budget/alarm/rate-limit base có.

### Week 2: Camera, Map, Nearby Scan

- MAP-005 Flutter Map Shell
- MAP-006 Camera + S3 Upload
- MAP-007 Nearby Hybrid Resolver
- MAP-008 Custom Place Candidate

**Exit Criteria:**
- User đứng tại vị trí, chụp ảnh, scan quanh khu vực.
- User chọn place có sẵn hoặc tạo custom candidate friends-visible.
- Duplicate prevention hoạt động.

### Week 3: Social Loop

- MAP-009 Saved Food List
- MAP-010 Mutual Friends
- MAP-011 Friends-only Check-in Feed
- MAP-012 Comments/Upvotes
- MAP-017 Rekognition Moderation

**Exit Criteria:**
- Bạn bè mutual xem được list/feed.
- Non-friend không xem được.
- Ảnh pending/approved/rejected đúng trạng thái.

### Week 4: Promotion, Admin, Release Hardening

- MAP-013 Promotion Candidate
- MAP-014 Promotion Score Engine
- MAP-015 Discover Feed
- MAP-016 Public Place Profile/Search/Rating
- MAP-018 Admin Review
- MAP-019 Merge Duplicate
- MAP-021 Test Matrix
- MAP-022 Android Internal Release

**Exit Criteria:**
- User đề xuất công khai được.
- Admin approve/merge/reject được.
- Public Place search/discover chỉ có approved place.
- Internal Android build sẵn sàng demo.

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

116 SP là scope đầy đủ để backlog không thiếu việc. Với mục tiêu 1 tháng, team cần cắt release theo "must-demo" nếu capacity thấp:

- **Must-demo:** MAP-001 đến MAP-013, MAP-017, MAP-018 basic approve/reject, MAP-020, MAP-021 smoke tests.
- **Can slip 1-2 tuần:** MAP-014 scoring nâng cao, MAP-015 Discover ranking, MAP-016 rating đầy đủ, MAP-019 merge nâng cao, MAP-022 store-ready polish.

---

## 8. Rủi ro chính và mitigation

### 8.1 Tạo địa điểm rác

- **Risk:** User spam custom place.
- **Mitigation:** 5/ngày/user, GPS proof, duplicate check 100m, admin approve trước public, trust score.

### 8.2 Duplicate địa điểm

- **Risk:** Nhiều user tạo cùng quán với tên khác nhau.
- **Mitigation:** normalized name, similarity >=85%, Google `place_id`, merge workflow, no hard delete.

### 8.3 Google Places cost spike

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
- Có cost/rate-limit guardrails cho AWS, Google fallback và SMS OTP.

