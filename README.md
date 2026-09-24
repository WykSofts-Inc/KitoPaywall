# KitoPaywall

**[Documentation](https://wyksofts-inc.github.io/KitoPaywall/documentation/kitopaywall/)**

StoreKit 2 paywalls for SwiftUI: six layouts, three plan pickers, a shimmering purchase button,
restore and legal links, a close button that fades in, and confetti when the purchase goes through.
`KitoStore` handles products, purchases, restores, `Transaction.updates` and entitlements. Part of
the [Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

## A paywall in two lines

```swift
@State private var store = KitoStore(productIDs: ["pro.monthly", "pro.yearly", "pro.lifetime"],
                                     mostPopular: "pro.yearly")

KitoPaywall(store: store, style: .hero)
```

The paywall loads the products, preselects the most popular plan, shows the trial and weekly price,
buys, verifies and finishes the transaction, celebrates, then dismisses itself.

## Layouts

```swift
KitoPaywall(store: store, style: .hero)           // drifting gradient, feature bullets, plan cards
KitoPaywall(store: store, style: .comparison)     // Free vs Pro table with ticks
KitoPaywall(store: store, style: .trialTimeline)  // Today → Day 5 reminder → Day 7 charge
KitoPaywall(store: store, style: .carousel)       // swipeable feature pages with page dots
KitoPaywall(store: store, style: .minimal)        // one plan, one big button
KitoPaywall(store: store, style: .luxe)           // near-black and gold, always dark
```

Every public view takes an optional `tint`; otherwise it uses `theme.colors.primary` from
`@Environment(\.kitoTheme)` (`.luxe` defaults to gold). Animations respect Reduce Motion.

## Your words

```swift
KitoPaywall(store: store, style: .comparison, content: KitoPaywallContent(
    title: "Design without limits",
    subtitle: "Every tool, every template, every export.",
    symbol: "paintbrush.pointed.fill",
    features: [
        KitoPaywallFeature("Unlimited projects", symbol: "folder.fill", free: .limited("3")),
        KitoPaywallFeature("Premium templates", symbol: "square.grid.2x2.fill"),
        KitoPaywallFeature("Cloud sync", symbol: "icloud.fill", free: .included),
    ],
    planPicker: .toggle,                 // .cards, .chips, .toggle; nil = the layout's choice
    termsURL: URL(string: "https://example.com/terms"),
    privacyURL: URL(string: "https://example.com/privacy"),
    closeButtonDelay: 3,
    celebrationTitle: "Welcome to Pro"
), tint: .purple)
```

## Presenting and gating

```swift
HomeView()
    .kitoPaywall(isPresented: $showsPaywall, store: store, style: .hero)

KitoProGate(store: store, paywall: .comparison) {
    InsightsView()
} locked: {
    InsightsTeaser()        // tapping it opens the paywall; the purchase reveals InsightsView
}
```

## The store

```swift
store.isPro                                  // owns any of the store's products
store.isEntitled("pro.lifetime")
store.purchasedProductIDs
store.activeSubscription?.isInTrial
store.activeSubscription?.expirationDate
store.activeSubscription?.willAutoRenew
store.activeSubscription?.state              // .active, .gracePeriod, .billingRetry
store.isEligibleForIntroOffer("pro.yearly")

switch await store.purchase(plan) {
case .purchased(let productID): unlock(productID)
case .pending: showAskToBuyNote()             // unlocks later through Transaction.updates
case .cancelled: break
case .failed(let error): show(error.localizedDescription)
}

await store.restore()                        // .restored, .nothingToRestore, .cancelled, .failed
```

Only verified transactions unlock anything. Every verified transaction is finished, including
ones that arrive while the app is closed (renewals, Ask to Buy, other devices).

## Previews without App Store Connect

```swift
KitoPaywall(store: .preview(), style: .trialTimeline)          // purchases succeed after a moment
KitoPaywall(store: .preview(plans: myPlans, isPro: true), style: .minimal)

let yearly = KitoPaywallPlan(id: "pro.yearly", price: 429, currencyCode: "KES", period: .yearly)
yearly.pricePerWeekText                                        // "KES 8.25/week"
yearly.savingsPercent(comparedTo: monthly)
KitoPaywallPlan.arranged(plans, mostPopular: "pro.yearly")     // sorted, badged, savings filled in
```

To buy real products while developing, add a StoreKit configuration file to your scheme's
Run action (Edit Scheme › Run › Options › StoreKit Configuration), and turn on the In-App
Purchase capability for the app target.

## Pieces for your own paywall

```swift
KitoPlanPicker(plans: store.plans, selection: $selection, style: .chips)
KitoPaywallButton("Start 7-day free trial", isLoading: isBuying) { buy() }
KitoTrialTimelineView(timeline: KitoTrialTimeline(trial: .weekly), priceText: "$59.99/year")
SomeView().kitoCelebration(isPresented: $celebrates)
```

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoPaywall.git", from: "0.1.0")
```

Requires iOS 17. The animated gradient uses `MeshGradient` on iOS 18 and blurred orbs on iOS 17.

## License

MIT — see [LICENSE](LICENSE).
