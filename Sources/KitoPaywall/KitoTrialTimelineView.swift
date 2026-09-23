//
//  KitoTrialTimelineView.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Today → reminder → charge, drawn as a track that fills in from the top.
public struct KitoTrialTimelineView: View {
    let timeline: KitoTrialTimeline
    let priceText: String?
    let tint: Color?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var ring = 0

    /// - Parameter priceText: What's charged at the end, e.g. "$59.99/year".
    public init(timeline: KitoTrialTimeline, priceText: String? = nil, tint: Color? = nil) {
        self.timeline = timeline
        self.priceText = priceText
        self.tint = tint
    }

    private var accent: Color { tint ?? theme.colors.primary }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(timeline.steps.enumerated()), id: \.element.id) { index, step in
                row(step, index: index, isLast: index == timeline.steps.count - 1)
            }
        }
        .onAppear {
            guard progress == 0 else { return }
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeInOut(duration: 1.2).delay(0.2)) { progress = 1 }
            }
            ring += 1
        }
    }

    private func row(_ step: KitoTrialTimeline.Step, index: Int, isLast: Bool) -> some View {
        let count = CGFloat(max(timeline.steps.count - 1, 1))
        let reached = progress >= CGFloat(index) / count - 0.001
        return HStack(alignment: .top, spacing: theme.spacing.lg) {
            ZStack {
                Circle()
                    .fill(reached ? AnyShapeStyle(LinearGradient(colors: [accent, accent.kitoShifted(30)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(theme.colors.surfaceMuted))
                Image(systemName: symbol(step.kind))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(reached ? accent.kitoContrast : theme.colors.onSurface.opacity(0.4))
                    .symbolEffect(.bounce, value: step.kind == .reminder ? ring : 0)
            }
            .frame(width: 38, height: 38)
            .shadow(color: reached ? accent.opacity(0.35) : .clear, radius: 8, y: 3)
            .scaleEffect(reached ? 1 : 0.85)
            .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.4), value: reached)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(step.title)
                    .font(theme.typography.bodyEmphasized.weight(.bold))
                    .foregroundStyle(theme.colors.onBackground)
                Text(detail(step))
                    .font(theme.typography.label.weight(.regular))
                    .foregroundStyle(theme.colors.onBackground.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, theme.spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : theme.spacing.xl)
        }
        .background(alignment: .topLeading) {
            if !isLast {
                let local = min(max(progress * count - CGFloat(index), 0), 1)
                GeometryReader { proxy in
                    ZStack(alignment: .top) {
                        Capsule().fill(theme.colors.surfaceMuted)
                        Capsule()
                            .fill(LinearGradient(colors: [accent, accent.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                            .frame(height: proxy.size.height * local)
                    }
                }
                .frame(width: 6)
                .padding(.top, 38 + theme.spacing.xs)
                .padding(.bottom, theme.spacing.xs)
                .padding(.leading, 16)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func symbol(_ kind: KitoTrialTimeline.Step.Kind) -> String {
        switch kind {
        case .start: return "lock.open.fill"
        case .reminder: return "bell.fill"
        case .charge: return "crown.fill"
        }
    }

    private func detail(_ step: KitoTrialTimeline.Step) -> String {
        let date = step.date.formatted(.dateTime.month(.abbreviated).day())
        switch step.kind {
        case .start:
            return "Get instant access to everything. No charge today."
        case .reminder:
            let left = max(0, (timeline.steps.last?.day ?? step.day) - step.day)
            let charge = timeline.chargeDate.formatted(.dateTime.month(.abbreviated).day())
            return "\(date): \(left) \(left == 1 ? "day" : "days") left. Cancel before \(charge) and you won't be charged."
        case .charge:
            let amount = priceText.map { "You'll be charged \($0)" } ?? "Your subscription starts"
            return "\(amount) on \(date). Cancel anytime before."
        }
    }
}
