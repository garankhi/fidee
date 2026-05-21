# MapVibe

**AI-driven map discovery platform** — Find the perfect place using natural language.

> *"Find a luxury rooftop restaurant with a city view open until midnight."*

---

## Repository Structure

```
mapvibe/
├── apps/
│   ├── mobile/       # Flutter mobile app (Android)
│   └── admin/        # React + TypeScript admin dashboard (Vite)
├── services/
│   └── api/          # TypeScript AWS Lambda microservices
├── infra/
│   └── cdk/          # AWS CDK infrastructure-as-code
├── docs/             # Product docs, architecture diagrams
├── package.json      # NPM workspaces root
└── README.md         # ← You are here
```

## Prerequisites

| Tool          | Version  | Purpose                     |
|---------------|----------|-----------------------------|
| Node.js       | ≥ 20 LTS | JS/TS workspaces            |
| npm           | ≥ 10     | Package management          |
| Flutter SDK   | ≥ 3.x    | Mobile app development      |
| AWS CLI v2    | latest   | AWS interaction             |
| AWS CDK CLI   | latest   | Infrastructure deployment   |

## Getting Started

```bash
# 1. Clone the repo
git clone <repo-url> && cd mapvibe

# 2. Install JS/TS dependencies (admin, api, cdk)
npm install

# 3. Flutter dependencies
cd apps/mobile && flutter pub get && cd ../..
```

## Development Commands

### All JS/TS Workspaces (from root)

```bash
npm run lint          # Lint all workspaces
npm run format        # Format all workspaces
npm run test          # Test all workspaces
npm run build         # Build all workspaces
npm run cdk:synth     # Build API/CDK and synth dev CloudFormation templates
npm run cdk:diff      # Show pending dev infrastructure changes
npm run cdk:deploy:dev # Deploy dev infrastructure
npm run cdk:diff:prod # Show prod infrastructure changes before release
```

### Flutter (apps/mobile)

```bash
cd apps/mobile
flutter analyze       # Lint
dart format .         # Format
flutter test          # Test
flutter run           # Run on connected device / emulator
```

### Individual Workspace

```bash
npm run lint  -w apps/admin      # Lint admin only
npm run test  -w services/api    # Test API only
npm run build -w infra/cdk       # Build CDK only
```

---

## ⚠️ Development & Testing Environment Policy

> [!CAUTION]
> **DO NOT use LocalStack or any local AWS emulator.**
>
> All development and testing **MUST** target real AWS environments:
>
> | Stage       | AWS Account / Profile | Purpose                        |
> |-------------|----------------------|--------------------------------|
> | `dev`       | `mapvibe-dev`        | Daily development & debugging  |
> | `prod`      | `mapvibe-prod`       | Production (deploy via CI/CD)  |
>
> **Rationale:** LocalStack introduces behavioral differences that mask real
> IAM, networking, and service-limit issues. Given our strict $200 budget,
> catching issues early on real AWS (with aggressive caching and on-demand
> pricing) is more cost-effective than debugging LocalStack discrepancies.

### CDK Commands

```bash
npm run cdk:synth      # Generate CloudFormation templates for dev
npm run cdk:diff       # Compare dev templates with deployed AWS stacks
npm run cdk:deploy:dev # Deploy dev stacks
npm run cdk:diff:prod  # Compare prod templates before release
```

`synth` renders CDK TypeScript into CloudFormation. `diff` shows what AWS would add, change, or delete. `deploy` applies the change to AWS.

`cdk:diff`, `cdk:deploy:dev`, and `cdk:diff:prod` require AWS credentials from `aws configure` or an AWS profile. `cdk:synth` can run locally without AWS credentials.

Main application stacks run in `ap-southeast-1`. The CloudFront media WAF runs in `us-east-1` because AWS requires `CLOUDFRONT` WebACLs there.

### GitHub Flow

```text
MAP-002-cdk-dev-prod -> PR into develop -> deploy dev -> PR develop into main -> tag release -> deploy prod
```

Task branches start with the Jira key, for example `MAP-002-cdk-dev-prod`. PR titles also start with the Jira key. Individual commits do not need Jira keys; squash merge keeps the Jira key in the final commit.

Jira issues do not need a required component or folder field; use acceptance criteria and the Jira key for traceability.

---

## Architecture

MapVibe is a **serverless, event-driven** application running on **AWS ap-southeast-1**.

Key services: **API Gateway → Lambda → DynamoDB**, **Amazon Bedrock** (AI search),
**Rekognition** (image moderation), **Cognito** (auth), **S3** (media), **CloudFront** (CDN).

See [System Architecture](docs/System_Architechture.png) and [PRD](docs/MapVibe_PRD.md) for details.

---

## License

See [LICENSE](LICENSE) for details.
