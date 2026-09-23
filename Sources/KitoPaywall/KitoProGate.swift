//
//  KitoProGate.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Shows `pro` to customers who own it and `locked` to everyone else. Tapping the locked
/// teaser opens the paywall; when the purchase lands, the teaser blurs away into the real thing.
///
/// ```swift
/// KitoProGate(store: store) {
///     InsightsView()
/// } locked: {
///     InsightsTeaser()
/// }
/// ```
public struct KitoProGate<Pro: View, Locked: View>: View {
    let store: KitoStore
    let productIDs: Set<String>?
    let paywall: KitoPaywallStyle?
    let content: KitoPaywallContent
    let tint: Color?
    let pro: () -> Pro
    let locked: () -> Locked

    @State private var showsPaywall = false

    /// - Parameters:
    ///   - productIDs: The products that unlock this content. `nil` means any of the store's.
    ///   - paywall: The paywall the teaser opens, or `nil` to leave the teaser inert.
    public init(
        store: KitoStore,
        productIDs: Set<String>? = nil,
        paywall: KitoPaywallStyle? = .hero,
        content: KitoPaywallContent = KitoPaywallContent(),
        tint: Color? = nil,
        @ViewBuilder pro: @escaping () -> Pro,
        @ViewBuilder locked: @escaping () -> Locked
    ) {
        self.store = store
        self.productIDs = productIDs
        self.paywall = paywall
        self.content = content
        self.tint = tint
        self.pro = pro
        self.locked = locked
    }

    private var isUnlocked: Bool {
        guard let productIDs else { return store.isPro }
        return !store.purchasedProductIDs.isDisjoint(with: productIDs)
    }

    public var body: some View {
        ZStack {
            if isUnlocked {
                pro().transition(.blurReplace)
            } else if paywall != nil {
                Button { showsPaywall = true } label: { locked() }
                    .buttonStyle(KitoPressableStyle(scale: 0.98))
                    .accessibilityHint(Text("Opens the upgrade screen"))
                    .transition(.blurReplace)
            } else {
                locked().transition(.blurReplace)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: isUnlocked)
        .kitoPaywall(isPresented: $showsPaywall, store: store, style: paywall ?? .hero, content: content, tint: tint)
    }
}
