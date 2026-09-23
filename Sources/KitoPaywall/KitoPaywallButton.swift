//
//  KitoPaywallButton.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The purchase button: a gradient capsule with a light sweep every few seconds, a breathing
/// glow, a spinner while `isLoading`, and a tap haptic.
public struct KitoPaywallButton: View {
    let title: String
    let subtitle: String?
    let isLoading: Bool
    let shimmers: Bool
    let tint: Color?
    let action: () -> Void

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var taps = 0

    public init(
        _ title: String,
        subtitle: String? = nil,
        isLoading: Bool = false,
        shimmers: Bool = true,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isLoading = isLoading
        self.shimmers = shimmers
        self.tint = tint
        self.action = action
    }

    private var accent: Color { tint ?? theme.colors.primary }
    private var foreground: Color { tint == nil ? theme.colors.onPrimary : accent.kitoContrast }

    public var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            ZStack {
                VStack(spacing: 2) {
                    Text(title).font(theme.typography.button)
                    if let subtitle {
                        Text(subtitle).font(theme.typography.caption).opacity(0.8)
                    }
                }
                .multilineTextAlignment(.center)
                .opacity(isLoading ? 0 : 1)
                .scaleEffect(isLoading ? 0.85 : 1)
                ProgressView()
                    .tint(foreground)
                    .opacity(isLoading ? 1 : 0)
                    .scaleEffect(isLoading ? 1 : 0.5)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, theme.spacing.xl)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                Capsule().fill(LinearGradient(colors: [accent.kitoShifted(-18, brightness: 0.06), accent, accent.kitoShifted(24, brightness: -0.06)],
                                              startPoint: .leading, endPoint: .trailing))
            }
            .overlay {
                if shimmers && !reduceMotion && isEnabled && !isLoading {
                    Shimmer().clipShape(Capsule()).allowsHitTesting(false)
                }
            }
            .overlay {
                Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .phaseAnimator([0.3, 0.55]) { view, glow in
                view.shadow(color: accent.opacity(reduceMotion || !isEnabled ? 0.3 : glow), radius: 18, y: 8)
            } animation: { _ in
                .easeInOut(duration: 1.6)
            }
            .opacity(isEnabled ? 1 : 0.55)
            .contentShape(Capsule())
        }
        .buttonStyle(KitoPressableStyle(scale: 0.96))
        .disabled(isLoading)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isLoading)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel(Text(subtitle.map { "\(title), \($0)" } ?? title))
        .accessibilityValue(Text(isLoading ? "In progress" : ""))
    }

    /// A diagonal band of light that crosses the button, then rests.
    private struct Shimmer: View {
        var body: some View {
            GeometryReader { proxy in
                LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 0.28)
                    .rotationEffect(.degrees(20))
                    .frame(height: proxy.size.height * 1.6)
                    .keyframeAnimator(initialValue: CGFloat(-0.4), repeating: true) { view, position in
                        view.offset(x: position * proxy.size.width, y: -proxy.size.height * 0.3)
                    } keyframes: { _ in
                        MoveKeyframe(-0.4)
                        CubicKeyframe(1.2, duration: 1.1)
                        LinearKeyframe(1.2, duration: 1.8)
                    }
                    .blendMode(.plusLighter)
            }
        }
    }
}
