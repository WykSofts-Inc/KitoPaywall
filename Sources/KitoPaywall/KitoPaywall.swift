//
//  KitoPaywall.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A complete paywall: plans from a `KitoStore`, a purchase button with loading state,
/// restore, legal links, a close button that fades in after a moment, error and pending
/// notices, and a confetti celebration when the purchase goes through.
///
/// ```swift
/// KitoPaywall(store: store, style: .hero)
/// ```
public struct KitoPaywall: View {
    let store: KitoStore
    let style: KitoPaywallStyle
    let content: KitoPaywallContent
    let tint: Color?
    let onPurchase: ((String) -> Void)?
    let onDismiss: (() -> Void)?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var celebrates = false
    @State private var celebrationTitle = ""
    @State private var purchasedID: String?
    @State private var notice: PaywallNotice?
    @State private var showsClose = false

    /// - Parameters:
    ///   - onPurchase: Called with the product ID once a purchase or restore has been celebrated.
    ///   - onDismiss: Called by the close button, and after a purchase when
    ///     `content.dismissesAfterPurchase`. Defaults to the environment's `dismiss`.
    public init(
        store: KitoStore,
        style: KitoPaywallStyle = .hero,
        content: KitoPaywallContent = KitoPaywallContent(),
        tint: Color? = nil,
        onPurchase: ((String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.store = store
        self.style = style
        self.content = content
        self.tint = tint
        self.onPurchase = onPurchase
        self.onDismiss = onDismiss
    }

    private var accent: Color {
        if let tint { return tint }
        return style == .luxe ? KitoPaywallStyle.gold : theme.colors.primary
    }

    private var paywallTheme: KitoTheme {
        style == .luxe ? LuxePaywallLayout.theme(from: theme, accent: accent) : theme
    }

    public var body: some View {
        layout
            .overlay(alignment: .topLeading) { closeButton }
            .overlay(alignment: .top) {
                if let notice {
                    PaywallNoticeBanner(notice: notice, accent: accent)
                        .padding(.top, theme.spacing.xxl + theme.spacing.lg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.notice = nil } }
                        .task(id: notice) {
                            try? await Task.sleep(for: .seconds(5))
                            guard !Task.isCancelled else { return }
                            withAnimation(.easeOut(duration: 0.3)) { self.notice = nil }
                        }
                }
            }
            .kitoCelebration(
                isPresented: $celebrates,
                title: celebrationTitle,
                message: content.celebrationMessage,
                symbol: content.symbol,
                tint: accent,
                onFinish: finishPurchase
            )
            .environment(\.kitoTheme, paywallTheme)
            .environment(\.colorScheme, style == .luxe ? .dark : colorSchemeFromTheme)
            .sensoryFeedback(.error, trigger: notice?.isError == true)
            .task {
                if !store.hasLoaded { await store.load() }
                selectDefaultIfNeeded()
            }
            .task {
                guard content.showsCloseButton else { return }
                if content.closeButtonDelay > 0 {
                    try? await Task.sleep(for: .seconds(content.closeButtonDelay))
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showsClose = true }
            }
            .onChange(of: store.plans) { selectDefaultIfNeeded() }
    }

    @Environment(\.colorScheme) private var colorSchemeFromTheme

    @ViewBuilder
    private var layout: some View {
        let context = PaywallContext(
            plans: store.plans,
            selection: $selection,
            content: content,
            accent: accent,
            isPurchasing: isPurchasing,
            isRestoring: isRestoring,
            loadError: store.plans.isEmpty && store.hasLoaded ? (store.errorMessage ?? "No plans are available right now.") : nil,
            ownedIDs: store.purchasedProductIDs,
            purchase: purchase,
            restore: restore,
            retry: { Task { await store.load() } }
        )
        switch style {
        case .hero: HeroPaywallLayout(context: context)
        case .comparison: ComparisonPaywallLayout(context: context)
        case .trialTimeline: TrialTimelinePaywallLayout(context: context)
        case .carousel: CarouselPaywallLayout(context: context)
        case .minimal: MinimalPaywallLayout(context: context)
        case .luxe: LuxePaywallLayout(context: context)
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if showsClose {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(paywallTheme.colors.onBackground.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(paywallTheme.colors.onBackground.opacity(0.08), lineWidth: 1))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(KitoPressableStyle(scale: 0.9))
            .padding(.leading, theme.spacing.md)
            .padding(.top, theme.spacing.xs)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .accessibilityLabel(Text("Close"))
        }
    }

    // MARK: Actions

    private var selectedPlan: KitoPaywallPlan? {
        store.plans.first { $0.id == selection } ?? KitoPaywallPlan.defaultSelection(in: store.plans)
    }

    private func selectDefaultIfNeeded() {
        guard selection == nil || !store.plans.contains(where: { $0.id == selection }) else { return }
        selection = KitoPaywallPlan.defaultSelection(in: store.plans)?.id
    }

    private func purchase() {
        guard let plan = selectedPlan, !isPurchasing else { return }
        if store.isEntitled(plan.id) {
            close()
            return
        }
        withAnimation { notice = nil }
        isPurchasing = true
        Task {
            let outcome = await store.purchase(plan)
            isPurchasing = false
            switch outcome {
            case .purchased(let id):
                celebrate(id, title: content.celebrationTitle)
            case .pending:
                show(PaywallNotice(message: "Your purchase is waiting for approval. Pro unlocks as soon as it goes through.", isError: false))
            case .cancelled:
                break
            case .failed(let error):
                show(PaywallNotice(message: error.errorDescription ?? "Something went wrong. Please try again.", isError: true))
            }
        }
    }

    private func restore() {
        guard !isRestoring else { return }
        withAnimation { notice = nil }
        isRestoring = true
        Task {
            let outcome = await store.restore()
            isRestoring = false
            switch outcome {
            case .restored:
                let id = store.productIDs.first { store.isEntitled($0) } ?? store.purchasedProductIDs.first ?? ""
                celebrate(id, title: "Welcome back")
            case .nothingToRestore:
                show(PaywallNotice(message: "No purchases to restore on this Apple Account.", isError: false))
            case .cancelled:
                break
            case .failed(let error):
                show(PaywallNotice(message: error.errorDescription ?? "Restore didn't work. Please try again.", isError: true))
            }
        }
    }

    private func celebrate(_ productID: String, title: String) {
        purchasedID = productID
        celebrationTitle = title
        withAnimation(.easeOut(duration: 0.25)) { celebrates = true }
    }

    private func finishPurchase() {
        guard let id = purchasedID else { return }
        purchasedID = nil
        onPurchase?(id)
        if content.dismissesAfterPurchase { close() }
    }

    private func show(_ notice: PaywallNotice) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { self.notice = notice }
    }

    private func close() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }
}

public extension View {
    /// Presents a `KitoPaywall` full screen while `isPresented` is true.
    func kitoPaywall(
        isPresented: Binding<Bool>,
        store: KitoStore,
        style: KitoPaywallStyle = .hero,
        content: KitoPaywallContent = KitoPaywallContent(),
        tint: Color? = nil,
        onPurchase: ((String) -> Void)? = nil
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            KitoPaywall(store: store, style: style, content: content, tint: tint, onPurchase: onPurchase) {
                isPresented.wrappedValue = false
            }
        }
    }
}
