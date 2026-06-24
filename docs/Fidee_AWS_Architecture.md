# Kiến trúc hệ thống AWS (Fidee AWS Architecture)

Tài liệu này mô tả chi tiết kiến trúc Cloud trên AWS của dự án Fidee (áp dụng cho cả môi trường `dev` và `prod`). Hệ thống được thiết kế theo hướng **100% Serverless & Event-Driven Architecture (EDA)** nhằm tối ưu chi phí, khả năng mở rộng và dễ bảo trì. Hạ tầng được tự động hoá hoàn toàn bằng **AWS CDK (TypeScript)**.

---

## 1. Mạng lưới & Bảo mật (Networking & Security)

### 1.1. Virtual Private Cloud (VPC)
- **Thiết kế No-NAT:** Hệ thống sử dụng mạng nội bộ hoàn toàn không có NAT Gateway để tiết kiệm 100% chi phí duy trì NAT.
- **Subnets:**
  - **Private Isolated Subnets:** Chứa Database (Aurora Serverless) và toàn bộ các AWS Lambda Functions. Các resources này không có đường truyền trực tiếp ra Internet.
  - **Public Subnets:** Chỉ dành riêng cho Bastion Host.
- **VPC Endpoints:** Để các Lambda trong Private Subnets gọi được dịch vụ AWS khác mà không cần Internet, hệ thống dùng:
  - *Gateway Endpoints:* cho Amazon DynamoDB và Amazon S3.
  - *Interface Endpoints:* cho AWS Secrets Manager.

### 1.2. Bảo mật bổ sung
- **AWS WAFv2 (Web Application Firewall):**
  - Áp dụng trên API Gateway (`ap-southeast-1`) và CloudFront (`us-east-1`).
  - Kích hoạt các tập luật bảo vệ có sẵn của AWS: Common Rule Set, Known Bad Inputs, IP Reputation và tự định nghĩa luật **Rate Limit** chống DDoS.
- **AWS Secrets Manager:** Quản lý tập trung thông tin nhạy cảm (như password kết nối Aurora PostgreSQL).
- **EC2 Bastion Host (Nano):** Cung cấp một điểm truy cập tạm thời an toàn (qua Session Manager) để kĩ sư có thể kết nối vào Database nội bộ.

---

## 2. API & Real-time (Giao tiếp & Thời gian thực)

### 2.1. REST API (Amazon API Gateway)
- **RESTful Endpoints:** Gateway duy nhất cho ứng dụng Mobile (ví dụ: `api.fidee.site/dev`).
- **Xác thực:** Sử dụng `Cognito User Pools Authorizer` tích hợp sẵn. Tất cả request bảo mật yêu cầu JWT Token ở Header.
- **CORS:** Cấu hình preflight toàn diện cho tất cả các HTTP Methods và Response chuẩn cho lỗi (4XX, 5XX).

### 2.2. WebSockets & Real-time (AWS AppSync)
- **GraphQL Subscriptions:** Dùng làm cầu nối WebSocket giữa Backend và Mobile App, cực kì phù hợp cho tính năng Chat 1-1 và Thông báo kết bạn.
- **Kiến trúc Local Resolvers:** Không kết nối trực tiếp Data Source từ AppSync. Thay vào đó, AppSync dùng `None Data Source` thuần tuý làm trạm phát trung chuyển (Publish-Subscribe).
  - Lambda gọi Mutation để "Publish" thông tin.
  - Mobile App gọi Subscription để "Lắng nghe" và nhận tin nhắn Push về máy theo thời gian thực (Real-time).

---

## 3. Compute (Xử lý Logic)

### AWS Lambda (Node.js 20)
Toàn bộ business logic được tách thành các hàm Lambda nhỏ (Microservices).
- **Core APIs:** Search, Xử lý Profile, Lấy danh sách địa điểm (Places), Bạn bè (Friends), v.v.
- **Real-time Event Triggers:** Lambda được kích hoạt bởi DynamoDB Streams để đẩy sự kiện tin nhắn/kết bạn qua AppSync.
- **Auth Triggers:** Các Lambda được hook thẳng vào vòng đời đăng nhập của Cognito để tùy chỉnh luồng OTP qua Email (Dùng dịch vụ Resend).

---

## 4. Database & Storage (Lưu trữ dữ liệu)

### 4.1. Relational Database (SQL)
- **Amazon Aurora Serverless v2 (PostgreSQL 16.4):**
  - Làm nguồn dữ liệu chân lý (Source of Truth) lưu trữ Quan hệ Bạn bè, Thông tin Conversation, Message, Lịch sử Check-in.
  - Khả năng tự động auto-scale (từ 0.5 đến 8 ACUs) khi tải thay đổi đột ngột nhưng có thể scale về mức gần 0 khi nhàn rỗi.

### 4.2. NoSQL Database (Amazon DynamoDB)
Sử dụng mô hình `PAY_PER_REQUEST` (On-Demand) siêu tiết kiệm.
- **`places`**: Bảng dữ liệu chính để phục vụ Search tốc độ cao (có GSI 1 và 2).
- **`user-profiles`**: Lưu thông tin cá nhân bổ sung của người dùng.
- **`friend-request-realtime-events` & `chat-realtime-events`**: Đóng vai trò làm "Event Store". Mọi tin nhắn hoặc yêu cầu kết bạn được ghi vào đây. Sau đó DynamoDB Stream sẽ capture sự kiện để kích hoạt hệ thống Real-time AppSync.
- **`chat-presence`**: Theo dõi trạng thái online, offline hoặc typing của người dùng trong khung chat.

### 4.3. Media Storage (Amazon S3 & CloudFront)
- **S3 Bucket (`MediaBucket`):** Nơi chứa ảnh Avatar và ảnh Check-in. Có chặn hoàn toàn quyền truy cập Public (Block Public Access).
- **Amazon CloudFront:** Đóng vai trò Content Delivery Network (CDN), giúp phân phối hình ảnh siêu tốc tới thiết bị di động.
  - Được cấu hình `Origin Access Control (OAC)` để đảm bảo người ngoài không thể tải ảnh trực tiếp từ S3 mà bắt buộc phải đi qua CloudFront.

---

## 5. Xác thực (Identity & Authentication)

### Amazon Cognito User Pools
- Quản lý quá trình Đăng ký / Đăng nhập.
- **Passwordless/Custom Flow:** Tự thiết kế luồng xác thực qua mã OTP Email thay vì nhập mật khẩu truyền thống, điều khiển bởi bộ ba Lambda Triggers (`DefineAuth`, `CreateAuth`, `VerifyAuth`).
- **RBAC (Role-Based Access Control):** Tích hợp tính năng phân quyền qua Cognito Groups: `Users`, `Moderators`, `Admins`.

---

## 6. Xử lý Bất đồng bộ (Async & Background Jobs)

### Amazon SQS (Simple Queue Service)
- **`media-upload-events` Queue:** Khi người dùng tải ảnh lên S3, một luồng xử lý nền sẽ được kích hoạt để phân tích hình ảnh, sinh ra Event đẩy vào SQS. Một Lambda Worker sẽ consume SQS này một cách tuần tự để cập nhật vào Database một cách đáng tin cậy.
- Có cấu hình thêm **Dead Letter Queue (DLQ)** để hứng lại các events bị lỗi nếu xử lý thất bại quá 3 lần.

---

## Sơ đồ tóm tắt luồng dữ liệu (Data Flow)

1. **Client (Mobile App)** -> `API Gateway` -> `AWS Lambda` -> `Aurora PostgreSQL / DynamoDB`.
2. **Client Upload Media** -> Gọi API cấp quyền -> Upload trực tiếp lên `S3` -> `SQS` -> `Lambda` xử lý ảnh.
3. **Chat Realtime Flow**: 
   - A gửi tin nhắn -> `API Gateway` -> `Chat Lambda` -> Ghi tin nhắn vào `Aurora` & `DynamoDB (chat-realtime-events)`.
   - `DynamoDB Stream` phát hiện có tin nhắn mới -> Kích hoạt `Publish Lambda` -> Gọi Mutation lên `AppSync`.
   - `AppSync` Push tin nhắn Real-time qua WebSocket về máy tính/điện thoại của B đang lắng nghe.
