# RevenueCat Webhook Integration

This app now uses RevenueCat entitlements as the subscription signal client-side.
For server-side source-of-truth, configure a RevenueCat webhook endpoint in your backend.

## Required webhook behavior

- Accept RevenueCat subscription lifecycle events.
- Identify user by RevenueCat `app_user_id`.
- Map active entitlement (`premium`) to backend fields:
  - `subscription_active`
  - `subscription_plan_id`
  - `subscription_source = "revenuecat_webhook"`
- Persist latest event timestamp/id to make processing idempotent.

## Event coverage

Handle, at minimum:

- `INITIAL_PURCHASE`
- `RENEWAL`
- `UNCANCELLATION`
- `CANCELLATION`
- `EXPIRATION`
- `BILLING_ISSUE`
- `PRODUCT_CHANGE`

## Reconciliation strategy

- Webhook is authoritative for backend persistence.
- App still sends best-effort updates through `putUserSettings` with source
  `revenuecat_listener`, `revenuecat_purchase`, or `revenuecat_restore` for fast UX.
- If webhook and app updates disagree, backend should trust webhook event state.

## Validation checklist

- Sandbox purchase updates backend to active.
- Restore on new device keeps backend active.
- Expiration/cancellation clears backend active status.
- Product change updates backend plan id.
- Duplicate webhook delivery does not produce duplicate state transitions.
