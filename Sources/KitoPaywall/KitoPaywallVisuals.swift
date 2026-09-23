//
//  KitoPaywallVisuals.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Colour helpers

extension Color {
    /// The same colour turned `degrees` around the hue wheel. Greys and black shift in
    /// brightness instead, so a black tint still gets a visible gradient.
    func kitoShifted(_ degrees: Double, brightness delta: Double = 0) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        if saturation < 0.12 {
            let step = CGFloat(abs(degrees) / 120) * 0.35 + CGFloat(delta)
            let value = brightness > 0.6 ? brightness - step : brightness + step
            return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(min(max(value, 0), 1)), opacity: Double(alpha))
        }
        // Yellows and golds turn green or orange after a few degrees, so move them less.
        let damping: Double = (0.05...0.2).contains(Double(hue)) ? 0.3 : 1
        var shifted = hue + CGFloat(degrees * damping / 360)
        shifted -= floor(shifted)
        let value = min(max(brightness + CGFloat(delta), 0), 1)
        return Color(hue: Double(shifted), saturation: Double(saturation), brightness: Double(value), opacity: Double(alpha))
    }

    /// Black or white, whichever reads better on this colour.
    var kitoContrast: Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return .white }
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? .black : .white
    }
}

extension KitoPaywallStyle {
    static let gold = Color(red: 0.87, green: 0.72, blue: 0.43)
}

// MARK: - Animated aurora

/// A slowly drifting mesh of the accent and two neighbouring hues. A mesh gradient on iOS 18,
/// blurred orbs on iOS 17, and still under Reduce Motion.
struct KitoAurora: View {
    let accent: Color
    var intensity: Double = 1
    /// Four colours to use instead of hues around `accent`.
    var colors: [Color]? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            content(time: time)
        }
        .opacity(intensity)
        .accessibilityHidden(true)
    }

    private var palette: [Color] {
        if let colors, colors.count >= 4 { return Array(colors.prefix(4)) }
        return [accent, accent.kitoShifted(38), accent.kitoShifted(-42), accent.kitoShifted(80, brightness: 0.1)]
    }

    @ViewBuilder
    private func content(time: Double) -> some View {
        if #available(iOS 18.0, *) {
            MeshGradient(width: 3, height: 3, points: meshPoints(time), colors: meshColors, smoothsColors: true)
        } else {
            orbs(time: time)
        }
    }

    private var meshColors: [Color] {
        let p = palette
        return [p[1], p[0], p[2],
                p[0], p[3], p[1],
                p[2], p[1], p[0]]
    }

    private func meshPoints(_ t: Double) -> [SIMD2<Float>] {
        func wave(_ speed: Double, _ phase: Double, _ amount: Double) -> Float {
            Float(sin(t * speed + phase) * amount)
        }
        return [
            [0, 0], [0.5 + wave(0.35, 0, 0.18), 0], [1, 0],
            [0, 0.5 + wave(0.3, 1, 0.16)], [0.5 + wave(0.42, 2, 0.2), 0.5 + wave(0.37, 3, 0.18)], [1, 0.5 + wave(0.28, 4, 0.16)],
            [0, 1], [0.5 + wave(0.33, 5, 0.18), 1], [1, 1],
        ]
    }

    private func orbs(time t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let p = palette
            ZStack {
                p[0]
                ForEach(0..<3, id: \.self) { index in
                    let i = Double(index)
                    Circle()
                        .fill(p[index + 1])
                        .frame(width: size.width * 0.9, height: size.width * 0.9)
                        .offset(
                            x: cos(t * (0.3 + i * 0.07) + i * 2) * size.width * 0.3,
                            y: sin(t * (0.25 + i * 0.05) + i) * size.height * 0.25
                        )
                        .blur(radius: 60)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }
}

// MARK: - Hero badge

/// A glossy rounded tile with the paywall's symbol, a soft glow, a gentle float and twinkles.
struct KitoHeroBadge: View {
    let symbol: String
    let accent: Color
    var size: CGFloat = 92

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.45))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: size * 0.35)
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [accent.kitoShifted(-25, brightness: 0.12), accent, accent.kitoShifted(30, brightness: -0.1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center))
                        .padding(1.5)
                        .blendMode(.plusLighter)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }
                .frame(width: size, height: size)
                .shadow(color: accent.opacity(0.5), radius: 18, y: 10)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(accent.kitoContrast)
                .symbolEffect(.bounce, value: appeared)
            twinkles
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .phaseAnimator([false, true]) { view, up in
            view.offset(y: reduceMotion ? 0 : (up ? -6 : 4))
                .rotationEffect(.degrees(reduceMotion ? 0 : (up ? 2 : -2)))
        } animation: { _ in
            .easeInOut(duration: 2.4)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) { appeared = true }
        }
        .accessibilityHidden(true)
    }

    private var twinkles: some View {
        ZStack {
            Twinkle(delay: 0).offset(x: size * 0.62, y: -size * 0.5)
            Twinkle(delay: 0.7).offset(x: -size * 0.66, y: -size * 0.2).scaleEffect(0.7)
            Twinkle(delay: 1.3).offset(x: size * 0.5, y: size * 0.55).scaleEffect(0.55)
        }
        .foregroundStyle(.white)
    }

    private struct Twinkle: View {
        let delay: Double
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .bold))
                .shadow(color: .white.opacity(0.8), radius: 4)
                .phaseAnimator([0.25, 1.0]) { view, value in
                    view.opacity(reduceMotion ? 0.8 : value).scaleEffect(reduceMotion ? 1 : 0.7 + value * 0.4)
                } animation: { _ in
                    .easeInOut(duration: 1.1).delay(delay)
                }
        }
    }
}

// MARK: - Press feedback

/// Springs down a touch while pressed.
struct KitoPressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Badge

struct KitoPlanBadgeView: View {
    let badge: KitoPlanBadge
    let accent: Color

    var body: some View {
        HStack(spacing: 3) {
            if badge == .bestValue { Image(systemName: "sparkles").font(.system(size: 9, weight: .bold)) }
            if badge == .mostPopular { Image(systemName: "flame.fill").font(.system(size: 9, weight: .bold)) }
            Text(badge.text.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
        }
        .foregroundStyle(accent.kitoContrast)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(LinearGradient(colors: [accent, accent.kitoShifted(30)], startPoint: .leading, endPoint: .trailing)))
        .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
        .fixedSize()
    }
}
