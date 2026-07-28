---
status: accepted
---

# DynamoDB is the online Pro authorization projection

RevenueCat remains the source of subscription evidence, while `user-profiles.plan` in DynamoDB is Fidey's single online projection for FREE/PRO authorization. PostgreSQL `user_subscriptions` retains billing and audit state, and profile responses read the same DynamoDB projection used by protected APIs; this adds a DynamoDB read to profile loading but avoids conflicting access decisions across screens and endpoints.

Reconciliation is idempotent and reports success only after the authorization projection and billing record are persisted. A webhook event is marked processed only after reconciliation completes, so delivery retries can repair partial failures.
