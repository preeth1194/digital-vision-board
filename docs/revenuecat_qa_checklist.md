# RevenueCat QA Checklist

Use this checklist during TestFlight / internal app sharing validation.

## Purchase flow

- [ ] New user sees paywall packages with live prices from RevenueCat offerings.
- [ ] Purchasing any package sets premium state immediately in app UI.
- [ ] Premium removes ad-gating in habit flows.
- [ ] Hosted RevenueCat paywall opens and returns valid result (`purchased`, `restored`, `cancelled`, `notPresented`, or `error`).
- [ ] Hosted paywall fallback to custom plan picker works when paywall is unavailable.

## Restore / cross-device

- [ ] Restore Purchases works after reinstall.
- [ ] Restore Purchases works on a second device signed into same store account.
- [ ] Subscription state persists after app restart.

## Expiry / cancellation

- [ ] Subscription cancellation is reflected after entitlement refresh cycle.
- [ ] Expired sandbox subscription removes premium access.

## Identity and migration

- [ ] Google-authenticated users resolve to stable appUserID (`dv user id`).
- [ ] Guest users resolve to deterministic anonymous appUserID.
- [ ] Legacy subscribed users remain unlocked during migration grace period.

## Backend alignment

- [ ] App sends best-effort subscription updates via `putUserSettings`.
- [ ] RevenueCat webhook events update backend subscription fields authoritatively.
- [ ] Backend and app agree on active plan id and subscription status.

## Customer Center

- [ ] “Manage Subscription” opens RevenueCat Customer Center from premium screen.
- [ ] Restore action from Customer Center updates in-app premium state.
- [ ] If Customer Center fails to open, app shows fallback guidance without crashing.
