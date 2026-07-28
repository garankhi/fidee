# Fidey

Fidey separates evidence of a paid subscription from the server-confirmed access granted to an account.

## Language

**Pro Entitlement**:
Active paid-subscription evidence reported by the billing provider. It triggers reconciliation but does not by itself authorize protected Fidey features.
_Avoid_: Pro Plan, payment, purchase

**Pro Plan**:
The server-confirmed account status that authorizes paid Fidey features.
_Avoid_: Pro Entitlement, subscription receipt

**Gallery Upload**:
An image or video selected from the device library for publishing as check-in media. Gallery Upload requires a Pro Plan and does not include selecting a Profile avatar.
_Avoid_: Camera Capture, Profile avatar, gallery browsing

**Camera Capture**:
An image captured inside Fidey with the in-app camera. Camera Capture remains available without a Pro Plan.
_Avoid_: Gallery Upload

**Pro Upgrade Entry**:
A visible action through which a Free account can intentionally open the Pro purchase flow without first encountering a locked feature.
_Avoid_: feature gate, subscription management

**Subscription Management Entry**:
The Profile action through which a Pro account can view or manage its existing subscription. Promotional Home upgrade actions are not shown to Pro accounts.
_Avoid_: Pro Upgrade Entry, paywall
