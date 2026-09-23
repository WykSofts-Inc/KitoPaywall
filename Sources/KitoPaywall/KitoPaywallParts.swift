//
//  KitoPaywallParts.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// What every layout needs from the paywall that hosts it.
struct PaywallContext {
    let plans: [KitoPaywallPlan]
    let selection: Binding<String?>
    let content: KitoPaywallContent
    let accent: Color
    let isPurchasing: Bool
    let isRestoring: Bool
    let loadError: String?
    let ownedIDs: Set<String>
    let purchase: () -> Void
    let restore: () -> Void
    let retry: () -> Void

    var selectedPlan: KitoPaywallPlan? {
        plans.first { $0.id == selection.wrappedValue } ?? KitoPaywallPlan.defaultSelection(in: plans)
    }

    var ownsSelection: Bool { selectedPlan.map { ownedIDs.contains($0.id) } ?? false }

    var callToAction: String {
        if ownsSelection { return "You're all set" }
        if let custom = content.callToAction { return custom }
        if let trial = selectedPlan?.trial { return "Start \(trial.trialLength) free trial" }
        return "Continue"
    }
}

// MARK: - Header

struct PaywallHeader: View {
    let context: PaywallContext
    var badgeSize: CGFloat = 88
    var showsBadge = true

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            if showsBadge {
                KitoHeroBadge(symbol: context.content.symbol, accent: context.accent, size: badgeSize)
                    .padding(.bottom, theme.spacing.md)
            }
            Text(context.content.title)
                .font(theme.typography.displayLarge.weight(.heavy))
                .foregroundStyle(theme.colors.onBackground)
                .accessibilityAddTraits(.isHeader)
            Text(context.content.subtitle)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onBackground.opacity(0.65))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Features

struct PaywallFeatureList: View {
    let features: [KitoPaywallFeature]
    let accent: Color
    var showsDetail = true

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                HStack(spacing: theme.spacing.md) {
                    Image(systemName: feature.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent.kitoContrast)
                        .frame(width: 36, height: 36)
                        .background {
                            RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous)
                                .fill(LinearGradient(colors: [accent.kitoShifted(-20, brightness: 0.06), accent.kitoShifted(25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        .shadow(color: accent.opacity(0.25), radius: 6, y: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.title)
                            .font(theme.typography.bodyEmphasized)
                            .foregroundStyle(theme.colors.onBackground)
                        if showsDetail, let detail = feature.detail {
                            Text(detail)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared || reduceMotion ? 0 : -18)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15 + Double(index) * 0.07), value: appeared)
                .accessibilityElement(children: .combine)
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Plans

/// The picker, a shimmering skeleton while products load, or the load error with a retry.
struct PaywallPlans: View {
    let context: PaywallContext
    let style: KitoPlanPickerStyle

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        if !context.plans.isEmpty {
            KitoPlanPicker(plans: context.plans, selection: context.selection, style: style, tint: context.accent)
        } else if let error = context.loadError {
            VStack(spacing: theme.spacing.md) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.colors.warning)
                Text(error)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button("Try again", action: context.retry)
                    .font(theme.typography.label.weight(.semibold))
                    .tint(context.accent)
            }
            .padding(theme.spacing.lg)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).fill(theme.colors.surfaceMuted))
        } else {
            KitoPlanPicker(plans: Array(KitoPaywallPlan.previewPlans.prefix(3)), selection: .constant(nil), style: style, tint: context.accent)
                .redacted(reason: .placeholder)
                .disabled(true)
                .phaseAnimator([0.45, 1.0]) { view, opacity in view.opacity(opacity) } animation: { _ in .easeInOut(duration: 0.8) }
                .accessibilityLabel(Text("Loading plans"))
        }
    }
}

// MARK: - Footer

struct PaywallFooter: View {
    let context: PaywallContext
    var fadesIn = true

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            KitoPaywallButton(context.callToAction, isLoading: context.isPurchasing, tint: context.accent, action: context.purchase)
                .disabled(context.selectedPlan == nil)
            if let plan = context.selectedPlan {
                Text(plan.terms)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .id(plan.id)
                    .transition(.opacity)
            }
            PaywallLegalLinks(context: context)
        }
        .animation(.easeInOut(duration: 0.2), value: context.selectedPlan?.id)
        .padding(.horizontal, theme.spacing.xl)
        .padding(.top, theme.spacing.lg)
        .padding(.bottom, theme.spacing.sm)
        .background {
            if fadesIn {
                LinearGradient(
                    stops: [.init(color: theme.colors.background.opacity(0), location: 0), .init(color: theme.colors.background, location: 0.3)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

/// "Restore purchases · Terms · Privacy".
struct PaywallLegalLinks: View {
    let context: PaywallContext

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        let ink = theme.colors.onBackground.opacity(0.55)
        HStack(spacing: theme.spacing.sm) {
            Button(action: context.restore) {
                ZStack {
                    Text("Restore purchases").opacity(context.isRestoring ? 0 : 1)
                    if context.isRestoring { ProgressView().controlSize(.mini) }
                }
            }
            .disabled(context.isRestoring)
            if let terms = context.content.termsURL {
                separator
                Link("Terms", destination: terms)
            }
            if let privacy = context.content.privacyURL {
                separator
                Link("Privacy", destination: privacy)
            }
        }
        .font(theme.typography.caption.weight(.medium))
        .foregroundStyle(ink)
        .tint(ink)
        .buttonStyle(.plain)
    }

    private var separator: some View {
        Text("·").accessibilityHidden(true)
    }
}

// MARK: - Notice

struct PaywallNotice: Equatable {
    var message: String
    var isError: Bool
}

struct PaywallNoticeBanner: View {
    let notice: PaywallNotice
    let accent: Color

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.sm) {
            Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(notice.isError ? theme.colors.danger : accent)
            Text(notice.message)
                .font(theme.typography.label)
                .foregroundStyle(theme.colors.onSurface)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .background {
            RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                .fill(theme.colors.surface)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                .strokeBorder((notice.isError ? theme.colors.danger : accent).opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal, theme.spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

/// Fades a layout's top edge into the background.
struct PaywallTopFade: ViewModifier {
    func body(content: Content) -> some View {
        content.mask(
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.5), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}
