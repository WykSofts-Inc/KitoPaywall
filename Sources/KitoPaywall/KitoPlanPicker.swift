//
//  KitoPlanPicker.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Plans to choose from, as stacked cards, side-by-side chips, or a monthly/yearly switch with a
/// big animated price. The selection springs between plans and ticks a selection haptic.
public struct KitoPlanPicker: View {
    let plans: [KitoPaywallPlan]
    @Binding var selection: String?
    let style: KitoPlanPickerStyle
    let tint: Color?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    public init(plans: [KitoPaywallPlan], selection: Binding<String?>, style: KitoPlanPickerStyle = .cards, tint: Color? = nil) {
        self.plans = plans
        self._selection = selection
        self.style = style
        self.tint = tint
    }

    private var accent: Color { tint ?? theme.colors.primary }
    private var selected: KitoPaywallPlan? { plans.first { $0.id == selection } ?? plans.first }
    private var spring: Animation { reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.72) }

    public var body: some View {
        Group {
            switch style {
            case .cards: cards
            case .chips: chips
            case .toggle: toggle
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func select(_ plan: KitoPaywallPlan) {
        withAnimation(spring) { selection = plan.id }
    }

    // MARK: Cards

    private var cards: some View {
        VStack(spacing: theme.spacing.md) {
            ForEach(plans) { plan in
                let isSelected = plan.id == selected?.id
                Button { select(plan) } label: { card(plan, isSelected: isSelected) }
                    .buttonStyle(KitoPressableStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.top, theme.spacing.sm)
    }

    private func card(_ plan: KitoPaywallPlan, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
        return HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle().strokeBorder(isSelected ? accent : theme.colors.border, lineWidth: 2)
                if isSelected {
                    Circle().fill(accent).padding(5)
                        .matchedGeometryEffect(id: "dot", in: namespace)
                }
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(plan.title).font(theme.typography.bodyEmphasized).foregroundStyle(theme.colors.onSurface)
                if !plan.summary.isEmpty {
                    Text(plan.summary).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.6))
                }
            }
            Spacer(minLength: theme.spacing.sm)
            VStack(alignment: .trailing, spacing: theme.spacing.xxs) {
                Text(plan.displayPrice).font(theme.typography.bodyEmphasized.weight(.bold)).foregroundStyle(theme.colors.onSurface)
                Text(plan.isLifetime ? "once" : "per \(plan.periodText)").font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.6))
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.lg)
        .background {
            shape.fill(theme.colors.surface)
            if isSelected {
                shape.fill(accent.opacity(0.09)).matchedGeometryEffect(id: "fill", in: namespace)
            }
        }
        .overlay {
            if isSelected {
                shape.strokeBorder(LinearGradient(colors: [accent, accent.kitoShifted(40)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .matchedGeometryEffect(id: "ring", in: namespace)
            } else {
                shape.strokeBorder(theme.colors.border, lineWidth: 1)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let badge = plan.badge {
                KitoPlanBadgeView(badge: badge, accent: accent)
                    .offset(x: -theme.spacing.lg, y: -10)
            }
        }
        .shadow(color: isSelected ? accent.opacity(0.18) : .clear, radius: 14, y: 6)
        .scaleEffect(isSelected ? 1 : 0.985)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(plan)))
    }

    // MARK: Chips

    @ViewBuilder
    private var chips: some View {
        if plans.count > 3 {
            ScrollView(.horizontal) {
                chipRow(width: 108)
                    .padding(.horizontal, theme.spacing.xs)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        } else {
            chipRow(width: nil)
        }
    }

    private func chipRow(width: CGFloat?) -> some View {
        HStack(spacing: theme.spacing.sm) {
            ForEach(plans) { plan in
                let isSelected = plan.id == selected?.id
                Button { select(plan) } label: {
                    chip(plan, isSelected: isSelected).frame(width: width)
                }
                .buttonStyle(KitoPressableStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.top, theme.spacing.md)
        .padding(.bottom, theme.spacing.xs)
    }

    private func chip(_ plan: KitoPaywallPlan, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
        let ink = isSelected ? accent.kitoContrast : theme.colors.onSurface
        return VStack(spacing: theme.spacing.xs) {
            Text(plan.period?.adjective ?? "Lifetime").font(theme.typography.label)
                .foregroundStyle(ink.opacity(0.85))
            Text(plan.displayPrice)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(ink)
            Text(plan.pricePerWeekText ?? "once")
                .font(theme.typography.caption)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(ink.opacity(0.7))
        }
        .padding(.vertical, theme.spacing.lg)
        .padding(.horizontal, theme.spacing.sm)
        .frame(maxWidth: .infinity)
        .background {
            shape.fill(theme.colors.surface)
            if isSelected {
                shape.fill(LinearGradient(colors: [accent, accent.kitoShifted(30, brightness: -0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .matchedGeometryEffect(id: "chip", in: namespace)
                    .shadow(color: accent.opacity(0.35), radius: 12, y: 6)
            }
        }
        .overlay { if !isSelected { shape.strokeBorder(theme.colors.border, lineWidth: 1) } }
        .overlay(alignment: .top) {
            if let badge = plan.badge ?? plan.savingsPercent.map(KitoPlanBadge.save) {
                KitoPlanBadgeView(badge: badge, accent: isSelected ? accent.kitoShifted(30) : accent).offset(y: -11)
            }
        }
        .scaleEffect(isSelected ? 1.03 : 1)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(plan)))
    }

    // MARK: Toggle

    private var toggle: some View {
        VStack(spacing: theme.spacing.lg) {
            HStack(spacing: 0) {
                ForEach(plans) { plan in
                    let isSelected = plan.id == selected?.id
                    Button { select(plan) } label: {
                        HStack(spacing: theme.spacing.xs) {
                            Text(plan.period?.adjective ?? "Lifetime")
                                .font(theme.typography.label.weight(.semibold))
                                .foregroundStyle(isSelected ? theme.colors.onSurface : theme.colors.onSurface.opacity(0.55))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if let savings = plan.savingsPercent, plans.count <= 3 {
                                Text("-\(savings)%")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(theme.colors.success)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(theme.colors.success.opacity(0.15)))
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                Capsule().fill(theme.colors.surface)
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "thumb", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(accessibilityText(plan)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Capsule().fill(theme.colors.surfaceMuted))

            if let plan = selected {
                VStack(spacing: theme.spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.xs) {
                        Text(plan.displayPrice)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(plan.isLifetime ? "once" : "/\(plan.periodText)")
                            .font(theme.typography.bodyEmphasized)
                            .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                            .contentTransition(.interpolate)
                    }
                    .foregroundStyle(theme.colors.onSurface)
                    HStack(spacing: theme.spacing.sm) {
                        if let perWeek = plan.pricePerWeekText, plan.period != .weekly {
                            Text("Just \(perWeek)").contentTransition(.numericText())
                        }
                        if let savings = plan.savingsPercent {
                            Text("Save \(savings)%")
                                .font(theme.typography.caption.weight(.bold))
                                .foregroundStyle(accent.kitoContrast)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(accent))
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.65))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func accessibilityText(_ plan: KitoPaywallPlan) -> String {
        var parts = [plan.title, plan.priceWithPeriod]
        if let trial = plan.trialText { parts.append(trial) }
        if let badge = plan.badge { parts.append(badge.text) }
        return parts.joined(separator: ", ")
    }
}
