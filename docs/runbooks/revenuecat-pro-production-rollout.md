# RevenueCat Pro Production Rollout

**Status:** Deployment blocked pending local verification and explicit `Fidee-dev` approval

**Last verified:** 2026-07-28, Asia/Bangkok

> **Canonical target decision:** Mapvibe no longer uses or plans to create `Fidee-prod`. All future backend deployments and Play builds intentionally target `Fidee-dev`. Do not propose `Fidee-prod` again unless the user explicitly reverses this decision.

## Verified AWS target state

The authenticated AWS identity is account `926883321458`. In `ap-southeast-1`, the current application resources are:

- CloudFormation application stack: `Fidee-dev` (`UPDATE_COMPLETE`)
- API Gateway: `fidee-dev-api`
- No `Fidee-prod` application stack was found

Nested stacks belonging to `Fidee-dev` are not separate release targets.

Do not infer a production target from `build-prod.ps1`, `cdk-outputs-prod.json`, or the word `prod` in a command name.

## Required deployment approval

The target decision is resolved: use `Fidee-dev` only. Before any deployment, migration, AAB build, or Play release, obtain explicit approval for that exact deployment/release action. Production Play builds must pass the intentional `-AllowDevBackendForProductionRelease` override.

The approval must name:

- AWS account
- exact CloudFormation stack
- region
- exact mobile API URL
- whether the dev-backend production override is intentional
- mobile build number and intended Play track

Plan approval alone does not authorize deployment or release.

## RevenueCat dashboard and AWS secret checklist

Verify without printing or placing secret values in shell history:

- RevenueCat project ID matches the selected environment configuration.
- The internal entitlement entity ID has lookup key `pro`.
- The RevenueCat v2 key has `customer_information:customers:read`.
- The webhook URL points to the selected stack.
- Webhook authorization matches the shared value stored in AWS.
- Production purchase lifecycle events are enabled.
- RevenueCat Customer Center is configured for the Android app before exposing `Quản lý gói`.
- AWS secret `fidee-{stage}-revenuecat-server` contains the server-side v2 key and webhook authorization value.
- Lambda environment variables contain only the deterministic secret name and non-secret identifiers, never raw keys. Do not pass the partial ARN returned by `Secret.fromSecretNameV2`; `GetSecretValue` must receive the secret name so the IAM wildcard matches the resolved complete ARN.

Required local environment identifiers before CDK synth/diff:

- `GOOGLE_CLIENT_ID`
- `REVENUECAT_PROJECT_ID`
- `REVENUECAT_PRO_ENTITLEMENT_ID`
- optional positive `REVENUECAT_TIMEOUT_MS` (defaults to 5000)

## Pre-deployment verification

Re-run immediately before any CDK action:

```powershell
cd E:\Project\mapvibe
aws sts get-caller-identity --output json
aws cloudformation list-stacks --region ap-southeast-1 --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE IMPORT_COMPLETE --query "StackSummaries[?starts_with(StackName, 'Fidee-')].[StackName,StackStatus]" --output table
aws apigateway get-rest-apis --region ap-southeast-1 --query "items[?contains(name, 'fidee')].[name,id]" --output table
```

After explicit deployment approval, run the dev diff:

```powershell
npm run cdk:diff
```

Do not run `cdk:diff:prod`; `Fidee-prod` is not a Mapvibe target.

Review migration, Lambda networking, IAM, secret references, Cognito output, and any unrelated dirty-workspace changes. Stop on an unexpected replacement or deletion.

## Backend-first deployment sequence

Only after separate explicit deployment approval:

1. Deploy the selected backend stack.
2. Invoke the selected stack's DB migration Lambda immediately.
3. Confirm migration `022_harden_revenuecat_reconciliation`.
4. Verify webhook delivery and reconciliation.
5. Run backend smoke checks.
6. Only then build the mobile artifact against the verified API.

Command sequence for the canonical `Fidee-dev` target:

```powershell
cd E:\Project\mapvibe
npm run cdk:deploy:dev
aws lambda invoke --region ap-southeast-1 --function-name fidee-dev-db-migrate --payload "{}" --cli-binary-format raw-in-base64-out services/api/response.json
Get-Content -Raw services/api/response.json
```

Even though `Fidee-dev` is the canonical target, each deployment and Play release still requires separate explicit approval.

## Backend smoke checks

Verify on the chosen deployed environment:

- Authenticated `POST /billing/revenuecat/sync` returns backend-confirmed `plan`, `entitlement`, and `reconciledAt`.
- An active subscriber becomes `PRO` in DynamoDB `user-profiles.plan`.
- `GET /profile` returns the same plan.
- Forged client entitlement fields cannot grant Pro.
- FREE gallery admission returns `403` with `code: PRO_PLAN_REQUIRED`.
- FREE in-app camera image and avatar upload remain allowed.
- Gallery images, gallery videos, and all videos require Pro.
- A webhook test event reaches `processed` or `pending_identity` as designed.
- A RevenueCat `TRANSFER` event reconciles every known user from both `transferred_from[]` and `transferred_to[]`; migration `022` records all of them in `resolved_user_ids` before the event becomes `processed`.
- Overlapping reconciliations for one user are serialized by a PostgreSQL session advisory lock through the DynamoDB projection update; PostgreSQL still commits before DynamoDB, and an unlock failure destroys the checked-out connection.
- Synthesized IAM for `fidee-dev-get-profile` and `fidee-dev-update-profile` contains exactly `dynamodb:GetItem` and `dynamodb:UpdateItem` for the profile table.
- CloudWatch logs contain no Google token, RevenueCat secret, authorization value, or raw RevenueCat payload.

## Mobile identity checks

Before a mobile release, verify that RevenueCat logs in with the authenticated Cognito `sub` before offerings, customer-info, purchase, or restore calls. Exercise logout and rapid account-switch cases and confirm that serialized SDK operations plus account-revision guards prevent a result from the previous user from updating current billing state. Billing must remain outside the SplashScreen gate.

## Mobile release gate

The approved rollout intentionally skips Play Internal Testing. This increases risk, so the following are mandatory:

- backend-first compatibility
- focused Flutter tests and `flutter analyze`
- verified Play signing configuration
- explicit new build number
- production artifact built with the selected stack outputs
- immediate smoke tests on the Play-distributed artifact
- active monitoring during the release window

Do not build an AAB or publish to Play until the exact stack/API/build/track approval is recorded.
