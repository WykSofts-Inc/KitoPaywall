//
//  KitoPaywallLayouts.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

// MARK: - Hero

/// Animated aurora, the badge and title, feature bullets, plan cards.
struct HeroPaywallLayout: View {
    let context: PaywallContext
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                ZStack {
                    KitoAurora(accent: context.accent)
                        .frame(height: 300)
                        .modifier(PaywallTopFade())
                    KitoHeroBadge(symbol: context.content.symbol, accent: context.accent)
                        .padding(.top, 40)
                }
                PaywallHeader(context: context, showsBadge: false)
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.top, -theme.spacing.xxl - theme.spacing.lg)
                PaywallFeatureList(features: context.content.features, accent: context.accent)
                    .padding(.horizontal, theme.spacing.xl)
                PaywallPlans(context: context, style: context.content.planPicker ?? .cards)
                    .padding(.horizontal, theme.spacing.xl)
            }
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(theme.colors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { PaywallFooter(context: context) }
    }
}

// MARK: - Comparison

/// Free vs Pro, feature by feature.
struct ComparisonPaywallLayout: View {
    let context: PaywallContext
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                PaywallHeader(context: context, badgeSize: 64)
                ComparisonTable(features: context.content.features, accent: context.accent)
                PaywallPlans(context: context, style: context.content.planPicker ?? .chips)
            }
            .padding(.horizontal, theme.spacing.xl)
            .padding(.top, theme.spacing.xxl + theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack(alignment: .top) {
                theme.colors.background
                KitoAurora(accent: context.accent, intensity: 0.45)
                    .frame(height: 280)
                    .modifier(PaywallTopFade())
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { PaywallFooter(context: context) }
    }
}

struct ComparisonTable: View {
    let features: [KitoPaywallFeature]
    let accent: Color

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let column: CGFloat = 62

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("What you get")
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                    .textCase(.uppercase)
                Spacer(minLength: theme.spacing.sm)
                Text("Free")
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                    .frame(width: column)
                Text("PRO")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(accent.kitoContrast)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(LinearGradient(colors: [accent, accent.kitoShifted(30)], startPoint: .leading, endPoint: .trailing)))
                    .frame(width: column)
            }
            .padding(.vertical, theme.spacing.md)

            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                Rectangle().fill(theme.colors.border.opacity(0.7)).frame(height: 1)
                HStack(spacing: 0) {
                    Text(feature.title)
                        .font(theme.typography.label)
                        .foregroundStyle(theme.colors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    cell(feature.free, isPro: false, index: index)
                        .frame(width: column)
                    cell(.included, isPro: true, index: index)
                        .frame(width: column)
                }
                .padding(.vertical, theme.spacing.md)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(feature.title). Free: \(spoken(feature.free)). Pro: included."))
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.xs)
        .background(alignment: .trailing) {
            RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(0.18), accent.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).strokeBorder(accent.opacity(0.35), lineWidth: 1)
                }
                .frame(width: column + 8)
                .padding(.vertical, theme.spacing.xs)
                .padding(.trailing, theme.spacing.lg - 4)
        }
        .background {
            RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).fill(theme.colors.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).strokeBorder(theme.colors.border, lineWidth: 1)
        }
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func cell(_ availability: KitoFeatureAvailability, isPro: Bool, index: Int) -> some View {
        switch availability {
        case .included:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isPro ? AnyShapeStyle(LinearGradient(colors: [accent, accent.kitoShifted(30)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(theme.colors.onSurface.opacity(0.3)))
                .scaleEffect(!isPro || appeared || reduceMotion ? 1 : 0.2)
                .opacity(!isPro || appeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.25 + Double(index) * 0.08), value: appeared)
        case .notIncluded:
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.25))
        case .limited(let text):
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
    }

    private func spoken(_ availability: KitoFeatureAvailability) -> String {
        switch availability {
        case .included: return "included"
        case .notIncluded: return "not included"
        case .limited(let text): return text
        }
    }
}

// MARK: - Trial timeline

/// Shows exactly when the trial reminds and charges, so starting one feels safe.
struct TrialTimelinePaywallLayout: View {
    let context: PaywallContext
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                PaywallHeader(context: context, badgeSize: 64)
                if let plan = context.selectedPlan, let timeline = plan.trialTimeline(reminderDaysBefore: context.content.reminderDaysBefore) {
                    VStack(alignment: .leading, spacing: theme.spacing.lg) {
                        Text("How your free trial works")
                            .font(theme.typography.titleMedium)
                            .foregroundStyle(theme.colors.onBackground)
                        KitoTrialTimelineView(timeline: timeline, priceText: plan.priceWithPeriod, tint: context.accent)
                            .id(plan.id)
                    }
                    .padding(theme.spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                            .fill(theme.colors.surface)
                            .shadow(color: context.accent.opacity(0.12), radius: 20, y: 8)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).strokeBorder(theme.colors.border, lineWidth: 1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    PaywallFeatureList(features: context.content.features, accent: context.accent)
                        .transition(.opacity)
                }
                PaywallPlans(context: context, style: context.content.planPicker ?? .toggle)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: context.selectedPlan?.trial)
            .padding(.horizontal, theme.spacing.xl)
            .padding(.top, theme.spacing.xxl + theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack(alignment: .top) {
                theme.colors.background
                KitoAurora(accent: context.accent, intensity: 0.3)
                    .frame(height: 240)
                    .modifier(PaywallTopFade())
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { PaywallFooter(context: context) }
    }
}

// MARK: - Carousel

/// One feature per page, swiped or auto-advancing, with page dots and the background hue
/// drifting from page to page.
struct CarouselPaywallLayout: View {
    let context: PaywallContext
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private var pages: [KitoPaywallFeature] {
        context.content.features.isEmpty
            ? [KitoPaywallFeature(context.content.title, detail: context.content.subtitle, symbol: context.content.symbol)]
            : context.content.features
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, feature in
                    CarouselPage(feature: feature, accent: pageAccent(index), isCurrent: page == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: 260)

            PageDots(count: pages.count, page: $page, accent: context.accent)
            PaywallPlans(context: context, style: context.content.planPicker ?? .chips)
                .padding(.horizontal, theme.spacing.xl)
                .padding(.top, theme.spacing.lg)
        }
        .background {
            ZStack {
                theme.colors.background
                KitoAurora(accent: pageAccent(page), intensity: 0.35)
                    .modifier(PaywallTopFade())
            }
            .animation(.easeInOut(duration: 0.8), value: page)
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { PaywallFooter(context: context) }
        .task(id: page) {
            guard !reduceMotion, pages.count > 1 else { return }
            try? await Task.sleep(for: .seconds(3.6))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { page = (page + 1) % pages.count }
        }
    }

    private func pageAccent(_ index: Int) -> Color {
        context.accent.kitoShifted(Double(index) * 22)
    }
}

private struct CarouselPage: View {
    let feature: KitoPaywallFeature
    let accent: Color
    let isCurrent: Bool

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            ZStack {
                ForEach(0..<2, id: \.self) { ring in
                    Circle()
                        .strokeBorder(accent.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 150 + CGFloat(ring) * 44, height: 150 + CGFloat(ring) * 44)
                        .phaseAnimator([false, true]) { view, out in
                            view.scaleEffect(reduceMotion ? 1 : (out ? 1.06 : 0.96)).opacity(out ? 0.4 : 1)
                        } animation: { _ in .easeInOut(duration: 1.8).delay(Double(ring) * 0.3) }
                }
                Circle()
                    .fill(accent.opacity(0.4))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                Circle()
                    .fill(LinearGradient(colors: [accent.kitoShifted(-20, brightness: 0.1), accent, accent.kitoShifted(30, brightness: -0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .frame(width: 124, height: 124)
                    .shadow(color: accent.opacity(0.45), radius: 20, y: 10)
                Image(systemName: feature.symbol)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(accent.kitoContrast)
                    .symbolEffect(.bounce, value: isCurrent)
            }
            .scaleEffect(isCurrent || reduceMotion ? 1 : 0.75)
            .rotationEffect(.degrees(isCurrent || reduceMotion ? 0 : -10))
            .animation(.spring(response: 0.55, dampingFraction: 0.65), value: isCurrent)
            .accessibilityHidden(true)

            VStack(spacing: theme.spacing.sm) {
                Text(feature.title)
                    .font(theme.typography.displayMedium.weight(.bold))
                    .foregroundStyle(theme.colors.onBackground)
                if let detail = feature.detail {
                    Text(detail)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.onBackground.opacity(0.65))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, theme.spacing.xxl)
            .opacity(isCurrent ? 1 : 0.3)
            .offset(y: isCurrent || reduceMotion ? 0 : 12)
            .animation(.easeOut(duration: 0.4), value: isCurrent)
        }
        .padding(.top, theme.spacing.xl)
    }
}

private struct PageDots: View {
    let count: Int
    @Binding var page: Int
    let accent: Color

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AnyShapeStyle(LinearGradient(colors: [accent, accent.kitoShifted(30)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(theme.colors.onBackground.opacity(0.18)))
                    .frame(width: index == page ? 24 : 7, height: 7)
                    .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { page = index } }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: page)
        .padding(.vertical, theme.spacing.sm)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(page + 1) of \(count)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: page = min(page + 1, count - 1)
            case .decrement: page = max(page - 1, 0)
            @unknown default: break
            }
        }
    }
}

// MARK: - Minimal

/// One plan, one price, one button.
struct MinimalPaywallLayout: View {
    let context: PaywallContext
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: theme.spacing.xxl + theme.spacing.lg)
                    PaywallHeader(context: context, badgeSize: 100)
                    Spacer(minLength: theme.spacing.xl)
                    price
                    Spacer(minLength: theme.spacing.xl)
                    PaywallFooter(context: context, fadesIn: false)
                        .padding(.horizontal, -theme.spacing.xl)
                }
                .padding(.horizontal, theme.spacing.xl)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .background {
            ZStack {
                theme.colors.background
                RadialGradient(colors: [context.accent.opacity(0.3), .clear], center: .top, startRadius: 20, endRadius: 460)
                RadialGradient(colors: [context.accent.kitoShifted(40).opacity(0.18), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 360)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var price: some View {
        if let plan = context.selectedPlan {
            VStack(spacing: theme.spacing.sm) {
                if let trial = plan.trialText {
                    Text(trial.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(context.accent)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(context.accent.opacity(0.12)))
                }
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.xs) {
                    Text(plan.displayPrice)
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(plan.isLifetime ? "once" : "/\(plan.periodText)")
                        .font(theme.typography.bodyEmphasized)
                        .foregroundStyle(theme.colors.onBackground.opacity(0.55))
                }
                .foregroundStyle(theme.colors.onBackground)
                if let perWeek = plan.pricePerWeekText, plan.period != .weekly {
                    Text("That's just \(perWeek)")
                        .font(theme.typography.label)
                        .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            PaywallPlans(context: context, style: .cards)
        }
    }
}

// MARK: - Luxe

/// Near-black with champagne gold, a serif title and a slowly turning emblem.
struct LuxePaywallLayout: View {
    let context: PaywallContext
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                LuxeEmblem(symbol: context.content.symbol, accent: context.accent)
                    .padding(.top, theme.spacing.xxl + theme.spacing.xl)
                VStack(spacing: theme.spacing.sm) {
                    Text("MEMBERSHIP")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(context.accent)
                    Text(context.content.title)
                        .font(.system(size: 36, weight: .medium, design: .serif))
                        .foregroundStyle(LinearGradient(colors: [theme.colors.onBackground, context.accent], startPoint: .top, endPoint: .bottom))
                        .accessibilityAddTraits(.isHeader)
                    Text(context.content.subtitle)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    ForEach(context.content.features) { feature in
                        HStack(spacing: theme.spacing.md) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(context.accent)
                            Text(feature.title)
                                .font(.system(size: 17, weight: .regular, design: .serif))
                                .foregroundStyle(theme.colors.onBackground.opacity(0.9))
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(theme.spacing.xl)
                .background {
                    RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.06), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [context.accent.opacity(0.6), context.accent.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }

                PaywallPlans(context: context, style: context.content.planPicker ?? .cards)
            }
            .padding(.horizontal, theme.spacing.xl)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack(alignment: .top) {
                theme.colors.background
                KitoAurora(accent: context.accent, intensity: 0.4, colors: [
                    Color(red: 0.16, green: 0.11, blue: 0.05),
                    context.accent.opacity(0.7),
                    Color(red: 0.05, green: 0.04, blue: 0.03),
                    Color(red: 0.45, green: 0.30, blue: 0.14),
                ])
                .frame(height: 420)
                .modifier(PaywallTopFade())
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { PaywallFooter(context: context) }
    }

    static func theme(from base: KitoTheme, accent: Color) -> KitoTheme {
        var theme = base
        let cream = Color(red: 0.97, green: 0.94, blue: 0.87)
        theme.colors = KitoColors(
            primary: accent, onPrimary: .black,
            secondary: accent, onSecondary: .black,
            background: Color(red: 0.035, green: 0.03, blue: 0.027), onBackground: cream,
            surface: Color(red: 0.085, green: 0.078, blue: 0.07), onSurface: cream,
            surfaceMuted: Color(red: 0.14, green: 0.13, blue: 0.11),
            border: accent.opacity(0.25),
            danger: base.colors.danger,
            success: Color(red: 0.62, green: 0.86, blue: 0.62),
            warning: accent
        )
        return theme
    }
}

private struct LuxeEmblem: View {
    let symbol: String
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.25))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
            Circle()
                .strokeBorder(AngularGradient(colors: [accent, accent.opacity(0.05), accent, accent.opacity(0.05), accent], center: .center), lineWidth: 1.5)
                .frame(width: 118, height: 118)
                .phaseAnimator([0.0, 360.0]) { view, angle in
                    view.rotationEffect(.degrees(reduceMotion ? 0 : angle))
                } animation: { phase in
                    phase == 0 ? nil : .linear(duration: 12)
                }
            Circle()
                .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                .frame(width: 96, height: 96)
            Image(systemName: symbol)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.94, blue: 0.78), accent, Color(red: 0.62, green: 0.45, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                .shadow(color: accent.opacity(0.6), radius: 10)
        }
        .accessibilityHidden(true)
    }
}
