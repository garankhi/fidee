---
status: accepted
---

# Backend authorizes Pro access

RevenueCat's active `pro` entitlement is treated as billing evidence, while the backend-confirmed `PRO` plan remains authoritative for protected Fidey features. After login, startup, purchase, or restore, the app reconciles the entitlement with the backend and unlocks Pro only after confirmation; this avoids client-only authorization and inconsistent access across devices, at the cost of showing a recoverable synchronization state when the backend is temporarily unavailable.

## Identity and concurrency decisions

- Every identity-sensitive RevenueCat SDK operation is serialized through one queue. The authenticated Cognito `sub` must be logged in to RevenueCat before offerings, customer info, purchase, or restore runs. Account-revision guards prevent late results from a previous user from mutating current billing state.
- Billing remains outside the SplashScreen gate; identity readiness is awaited only when a billing action needs it.
- RevenueCat `TRANSFER` events resolve candidates from both `transferred_from[]` and `transferred_to[]`, reconcile every known source and destination user, and mark the event processed only after all resolved users succeed. Migration `022` therefore stores `resolved_user_ids TEXT[]`.
- Reconciliation is serialized per Fidey user with a PostgreSQL session advisory lock. The locked pool connection executes the PostgreSQL transaction, PostgreSQL commits before the DynamoDB projection update, and the lock remains held until that update finishes. If advisory unlock fails, the connection is destroyed instead of returning a potentially locked session to the pool.
- The profile GET and PATCH Lambdas receive only `dynamodb:GetItem` and `dynamodb:UpdateItem` for `user-profiles`, matching both profile access and the shared authentication projection sync.
