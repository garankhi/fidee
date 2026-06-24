# Quy trình phát triển Fidee

> Hướng dẫn từng bước: từ nhận ticket → code → test → tạo PR → deploy.

---

## Tổng quan quy trình

```
Nhận ticket → Tạo branch → Code → Viết test → Chạy lint/test → Tạo PR → Review → Merge → Deploy
```

---

## Bước 1 — Nhận ticket và hiểu yêu cầu

Trước khi code, đảm bảo bạn hiểu rõ:

- [ ] Ticket yêu cầu gì? (feature mới, fix bug, hay refactor?)
- [ ] Ảnh hưởng đến workspace nào? (`mobile`, `admin`, `api`, `cdk`?)
- [ ] Có cần thay đổi infrastructure không? (thêm table, thêm Lambda?)
- [ ] Acceptance criteria là gì?

> **Nếu chưa rõ → hỏi ngay.** Không đoán, không tự suy diễn.

---

## Bước 2 — Tạo branch

```bash
# Cập nhật develop mới nhất
git checkout develop
git pull origin develop

# Tạo branch mới
git checkout -b MAP-002-cdk-dev-prod

# Ví dụ:
git checkout -b MAP-002-cdk-dev-prod
git checkout -b MAP-004-cognito-auth
git checkout -b MAP-007-nearby-place-scan
```

### Quy ước đặt tên branch

- Format: `<JIRAKEY>-<mo-ta-ngan>`, ví dụ `MAP-002-cdk-dev-prod`.
- Không dùng prefix `feature/`, `fix/`, `hotfix/`.
- Mỗi Jira issue tạo một branch và một PR vào `develop`.
- Jira issue không cần bắt buộc component/folder; acceptance criteria quan trọng hơn.

---

## Bước 3 — Code

### Xác định folder làm việc

| Bạn cần làm gì? | Folder | Lệnh khởi chạy |
|------------------|--------|-----------------|
| Sửa/thêm UI admin | `apps/admin/src/` | `npm run dev -w apps/admin` |
| Sửa/thêm API endpoint | `services/api/src/handlers/` | — (không cần dev server) |
| Sửa/thêm AWS resource | `infra/cdk/lib/` | — |
| Sửa/thêm mobile UI | `apps/mobile/lib/` | `cd apps/mobile && flutter run` |

### Ví dụ thực tế: Thêm một API endpoint mới

**Bài toán:** Tạo endpoint `GET /places/:id` trả về chi tiết một place.

#### 3a. Tạo handler mới

```typescript
// services/api/src/handlers/get-place.ts

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  const placeId = event.pathParameters?.id;

  if (!placeId) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Missing place ID' }),
    };
  }

  // TODO: Query DynamoDB
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id: placeId,
      name: 'Placeholder',
    }),
  };
};
```

#### 3b. Viết test ngay

```typescript
// services/api/src/handlers/get-place.test.ts

import { describe, it, expect } from 'vitest';
import { handler } from './get-place';
import { APIGatewayProxyEvent } from 'aws-lambda';

const mockEvent = (pathParams: Record<string, string> | null) =>
  ({
    pathParameters: pathParams,
    body: null,
    headers: {},
    httpMethod: 'GET',
    isBase64Encoded: false,
    path: '/places',
    queryStringParameters: null,
    requestContext: {} as APIGatewayProxyEvent['requestContext'],
    resource: '',
  }) as unknown as APIGatewayProxyEvent;

describe('get-place handler', () => {
  it('returns 400 when place ID is missing', async () => {
    const result = await handler(mockEvent(null));
    expect(result.statusCode).toBe(400);
  });

  it('returns 200 with place data', async () => {
    const result = await handler(mockEvent({ id: 'place-123' }));
    expect(result.statusCode).toBe(200);

    const body = JSON.parse(result.body);
    expect(body.id).toBe('place-123');
  });
});
```

#### 3c. Nếu cần thêm infrastructure (Lambda + API Gateway route)

```typescript
// infra/cdk/lib/fidee-stack.ts — thêm vào cuối constructor

const getPlaceFn = new lambda.Function(this, 'GetPlaceFunction', {
  functionName: `fidee-get-place-${stage}`,
  runtime: lambda.Runtime.NODEJS_20_X,
  handler: 'handlers/get-place.handler',
  code: lambda.Code.fromAsset('../../services/api/dist'),
  environment: {
    PLACES_TABLE: placesTable.tableName,
  },
});

placesTable.grantReadData(getPlaceFn);

const placesResource = api.root.addResource('places');
const placeByIdResource = placesResource.addResource('{id}');
placeByIdResource.addMethod('GET', new apigateway.LambdaIntegration(getPlaceFn));
```

---

## Bước 4 — Kiểm tra code

### Chạy theo thứ tự

```bash
# 1. Format — sửa style tự động
npm run format

# 2. Lint — kiểm tra lỗi logic/style
npm run lint

# 3. Test — kiểm tra code chạy đúng
npm run test

# 4. Nếu sửa Flutter
cd apps/mobile
dart format .
flutter analyze
flutter test
```

### Kết quả mong đợi

```
✅ Format  — không có file nào thay đổi (đã đúng format)
✅ Lint    — không có error (warning chấp nhận được)
✅ Test    — "All tests passed" hoặc "X passed (X)"
```

### Nếu test fail?

```bash
# Chạy test cho riêng workspace đang sửa, xem chi tiết lỗi
npm run test -w services/api

# Chạy ở chế độ watch — tự chạy lại khi save file
npm run test:watch -w services/api
```

---

## Bước 5 — Commit

### Quy ước commit message

```
<type>(<scope>): <mô tả ngắn>
```

| Type | Khi nào dùng | Ví dụ |
|------|-------------|-------|
| `feat` | Thêm tính năng mới | `feat(api): add get-place endpoint` |
| `fix` | Sửa bug | `fix(admin): fix stat card not rendering` |
| `refactor` | Tái cấu trúc, không đổi behavior | `refactor(api): extract validation util` |
| `test` | Thêm/sửa test | `test(cdk): add S3 bucket policy test` |
| `docs` | Cập nhật tài liệu | `docs: update CONTRIBUTING guide` |
| `chore` | Config, CI, dependencies | `chore: update vitest to v3.2` |

### Ví dụ

```bash
git add .
git commit -m "feat(api): add get-place endpoint

- Create GET /places/:id handler
- Return 400 if place ID missing
- Add unit tests for both cases"
```

### Nguyên tắc commit

- ✅ Mỗi commit là **một thay đổi logic** (không trộn nhiều thứ)
- ✅ Commit message viết bằng **tiếng Anh**
- ✅ Dòng đầu ≤ 72 ký tự
- ❌ Không commit file `node_modules/`, `dist/`, `.env`

---

## Bước 6 — Push và tạo Pull Request

```bash
git push origin MAP-002-cdk-dev-prod
```

### Nội dung PR cần có

```markdown
## Mô tả
Thêm endpoint GET /places/:id trả về chi tiết một place.

## Thay đổi
- [x] `services/api/src/handlers/get-place.ts` — handler mới
- [x] `services/api/src/handlers/get-place.test.ts` — unit test
- [x] `infra/cdk/lib/fidee-stack.ts` — thêm Lambda + API route

## Test
- `npm run test` — 12/12 passed
- Manual test trên AWS dev: `curl https://xxx.execute-api.ap-southeast-1.amazonaws.com/dev/places/abc`

## Checklist
- [x] Code đã format (`npm run format`)
- [x] Lint pass (`npm run lint`)
- [x] Test pass (`npm run test`)
- [x] Không có secret/credential trong code
```

---

## Bước 7 — Code Review

### Người review kiểm tra

- [ ] Code có đọc hiểu được không?
- [ ] Có test cover đủ case không?
- [ ] Có ảnh hưởng đến cost AWS không? (thêm Lambda, thêm table?)
- [ ] Có lỗ hổng bảo mật không? (missing auth, public S3?)

### Sau khi được approve

```bash
# Merge vào develop (trên GitHub/GitLab UI)
# Hoặc dùng lệnh:
git checkout develop
git merge MAP-002-cdk-dev-prod
git push origin develop
```

---

## Bước 8 — Deploy

### Deploy lên dev (sau khi merge vào develop)

```bash
npm run cdk:synth      # Sinh CloudFormation template cho dev
npm run cdk:diff       # Xem thay đổi dev trước deploy
npm run cdk:deploy:dev # Deploy dev
```

### Kiểm tra prod trước release

```bash
npm run cdk:diff:prod  # Xem diff prod, không deploy
```

`synth` render CDK TypeScript thành CloudFormation. `diff` so template mới với stack đang có trên AWS. `deploy` apply thay đổi thật lên AWS.

`cdk:diff`, `cdk:deploy:dev`, và `cdk:diff:prod` cần AWS credentials từ `aws configure` hoặc AWS profile. `cdk:synth` có thể chạy local không cần credentials.

Stack chính chạy ở `ap-southeast-1`. Riêng WAF gắn CloudFront media chạy ở `us-east-1` vì AWS bắt buộc WebACL scope `CLOUDFRONT` ở region này.

### Release prod

```bash
# Sau khi dev ổn, tạo PR develop -> main.
# Sau khi merge main:
git checkout main
git pull origin main
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Prod deploy chạy từ tag release sau khi đã kiểm tra `npm run cdk:diff:prod`.

### Kiểm tra sau deploy

```bash
# Xem API URL từ CDK output
# Test endpoint
curl -X POST https://<api-url>/dev/search \
  -H "Content-Type: application/json" \
  -d '{"prompt": "rooftop restaurant"}'
```

---

## Tóm tắt — Checklist trước khi tạo PR

```
✅ Branch tạo từ develop mới nhất
✅ Branch và PR title bắt đầu bằng Jira key
✅ Code theo đúng cấu trúc folder
✅ Có test cho code mới
✅ npm run format   — pass
✅ npm run lint     — pass
✅ npm run test     — pass
✅ PR có mô tả đầy đủ
```
