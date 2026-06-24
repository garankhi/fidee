# Billing Contract

## Product Rules

Fidee Pro development mode uses RevenueCat Test Store. App Store Connect and Google Play Console are not required for this phase.

- Entitlement: `pro`
- Products: `fidee_pro_monthly`, `fidee_pro_yearly`
- RevenueCat App User ID: authenticated Cognito `sub`
- Client paywall: custom Fidee bottom sheet
- Server source of truth: API subscription state and `users.plan`

## POST /billing/revenuecat/sync

Authenticated by Cognito. The `appUserId` must match the Cognito `sub` in the request token.

Request:

```json
{
  "appUserId": "cognito-sub",
  "activeEntitlementIds": ["pro"],
  "productId": "fidee_pro_monthly",
  "store": "TEST_STORE"
}
```

Success response:

```json
{
  "status": "success",
  "data": {
    "plan": "PRO",
    "entitlement": "pro"
  }
}
```

Behavior:

- If `activeEntitlementIds` contains `pro`, persist `PRO`.
- Otherwise persist `FREE`.
- Reject a request when `appUserId` does not match the authenticated user.
- The app should call sync after purchase, restore, or customer-info refresh.

## POST /billing/revenuecat/webhook

Public RevenueCat webhook endpoint protected by a shared secret header.

Headers:

```text
X-RevenueCat-Signature: <configured webhook secret>
Content-Type: application/json
```

Expected event payload shape:

```json
{
  "event": {
    "id": "revenuecat-event-id",
    "app_user_id": "cognito-sub",
    "type": "INITIAL_PURCHASE",
    "product_id": "fidee_pro_yearly",
    "entitlement_ids": ["pro"],
    "expiration_at_ms": 1781580000000,
    "store": "TEST_STORE"
  }
}
```

Behavior:

- Webhook events are idempotent by RevenueCat event id.
- Active entitlement events update subscription state to `PRO`.
- Expiration, cancellation, refund, or revoke events remove active Pro access and update plan to `FREE`.
- Unknown event types should be stored or ignored safely without granting Pro access.

## Feature Enforcement

The API must enforce Pro-dependent behavior server-side.

- AI quota: Free 5 input/day, Pro 50 input/day, reset by server-side date.
- Video upload/check-in: Pro only, max 3 seconds, video upload under 20MB, GPS proof required.
- Temp place visibility: Free for all users, `FRIENDS` by default, `PRIVATE` visible only to creator.
