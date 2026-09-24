# ``KitoPaywall``

StoreKit 2 paywalls for SwiftUI, with six layouts, plan pickers and a store that manages purchases and entitlements.

## Overview

``KitoStore`` wraps StoreKit 2 in one observable object. It loads your products,
buys and restores them, listens to `Transaction.updates` for purchases made
elsewhere — renewals, Ask to Buy, other devices — and finishes every verified
transaction. Only verified transactions unlock anything.

``KitoPaywall/KitoPaywall`` puts a complete paywall on screen from that store. It
loads the products, preselects the most popular plan, shows the trial and weekly
price, completes the purchase, celebrates, then dismisses itself.

```swift
@State private var store = KitoStore(productIDs: ["pro.monthly", "pro.yearly", "pro.lifetime"],
                                     mostPopular: "pro.yearly")

var body: some View {
    KitoPaywall(store: store, style: .hero)
}
```

Choose one of six ``KitoPaywallStyle`` layouts and supply your own copy and
feature list with ``KitoPaywallContent``. Present a paywall with the
`kitoPaywall(isPresented:store:style:)` modifier, or wrap premium screens in
``KitoProGate`` so tapping the locked content opens the paywall. For previews
without App Store Connect, `KitoStore.preview()` offers the same API with
simulated purchases.

The individual pieces — ``KitoPlanPicker``, ``KitoPaywallButton`` and
``KitoTrialTimelineView`` — are public too, for building your own paywall. Every
view takes an optional `tint` and otherwise falls back to
`theme.colors.primary` from the Kito theme.

## Topics

### Paywalls

- ``KitoPaywall/KitoPaywall``
- ``KitoPaywallStyle``
- ``KitoPaywallContent``
- ``KitoPaywallFeature``
- ``KitoFeatureAvailability``
- ``KitoProGate``

### Store and Entitlements

- ``KitoStore``
- ``KitoActiveSubscription``
- ``KitoPurchaseOutcome``
- ``KitoRestoreOutcome``
- ``KitoStoreError``

### Plans

- ``KitoPaywallPlan``
- ``KitoBillingPeriod``
- ``KitoPlanBadge``

### Building Blocks

- ``KitoPlanPicker``
- ``KitoPlanPickerStyle``
- ``KitoPaywallButton``
- ``KitoTrialTimelineView``
- ``KitoTrialTimeline``
