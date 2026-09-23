//
//  KitoCelebration.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

public extension View {
    /// Confetti from both bottom corners and a "Welcome to Pro" card, with a success haptic.
    /// Clears `isPresented` on its own after a few seconds, or when tapped. Under Reduce Motion
    /// the card simply fades in.
    func kitoCelebration(
        isPresented: Binding<Bool>,
        title: String = "Welcome to Pro",
        message: String? = "Everything is unlocked. Enjoy!",
        symbol: String = "crown.fill",
        tint: Color? = nil,
        onFinish: (() -> Void)? = nil
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                KitoCelebrationView(title: title, message: message, symbol: symbol, tint: tint) {
                    withAnimation(.easeOut(duration: 0.3)) { isPresented.wrappedValue = false }
                    onFinish?()
                }
                .transition(.opacity)
            }
        }
    }
}

struct KitoCelebrationView: View {
    let title: String
    let message: String?
    let symbol: String
    let tint: Color?
    let onFinish: () -> Void

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var finished = false

    private var accent: Color { tint ?? theme.colors.primary }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
            if !reduceMotion {
                KitoConfetti(colors: [accent, accent.kitoShifted(40), accent.kitoShifted(-50), theme.colors.warning, theme.colors.success, .white])
                    .ignoresSafeArea()
            }
            VStack(spacing: theme.spacing.lg) {
                KitoHeroBadge(symbol: symbol, accent: accent, size: 84)
                    .padding(.bottom, theme.spacing.sm)
                Text(title)
                    .font(theme.typography.displayMedium.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface)
                if let message {
                    Text(message)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.onSurface.opacity(0.7))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, theme.spacing.xxl)
            .padding(.vertical, theme.spacing.xxl)
            .background {
                RoundedRectangle(cornerRadius: theme.radii.xl * 1.4, style: .continuous)
                    .fill(theme.colors.surface)
                    .shadow(color: accent.opacity(0.3), radius: 30, y: 14)
            }
            .padding(.horizontal, theme.spacing.xl)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .sensoryFeedback(.success, trigger: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: Text("Continue"), finish)
        .task {
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.62)) { appeared = true }
            try? await Task.sleep(for: .seconds(2.8))
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

/// Paper confetti fired from both bottom corners: it rises, slows, tumbles and flutters down.
struct KitoConfetti: View {
    let colors: [Color]
    var count = 130

    @State private var start = Date.now
    @State private var pieces: [Piece] = []
    @State private var isDone = false

    struct Piece {
        var fromLeft: Bool
        var angle: Double
        var speed: Double
        var spin: Double
        var flip: Double
        var phase: Double
        var sway: Double
        var width: Double
        var height: Double
        var color: Int
        var isRound: Bool
    }

    var body: some View {
        TimelineView(.animation(paused: isDone)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    draw(piece, at: t, in: size, context: context)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            start = .now
            pieces = (0..<count).map { index in
                let fromLeft = index.isMultiple(of: 2)
                let spread = Double.random(in: -0.32...0.32)
                return Piece(
                    fromLeft: fromLeft,
                    angle: (fromLeft ? -1.08 : -2.06) + spread,
                    speed: Double.random(in: 1.3...2.3),
                    spin: Double.random(in: -7...7),
                    flip: Double.random(in: 4...11),
                    phase: Double.random(in: 0...(2 * .pi)),
                    sway: Double.random(in: 6...18),
                    width: Double.random(in: 6...10),
                    height: Double.random(in: 9...15),
                    color: Int.random(in: 0..<max(colors.count, 1)),
                    isRound: Int.random(in: 0..<5) == 0
                )
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(4.5))
            isDone = true
        }
    }

    private func draw(_ piece: Piece, at t: Double, in size: CGSize, context: GraphicsContext) {
        guard !colors.isEmpty else { return }
        let drag = 2.4
        let travel = size.height * piece.speed * (1 - exp(-drag * t)) / drag
        let fall = 0.5 * size.height * 0.28 * t * t
        let x = (piece.fromLeft ? 0 : size.width) + cos(piece.angle) * travel + sin(t * 2.2 + piece.phase) * piece.sway * min(t, 1)
        let y = size.height + sin(piece.angle) * travel + fall
        let alpha = t < 3 ? 1 : max(0, 1 - (t - 3) / 1.2)
        guard alpha > 0, y < size.height + 40 || t < 0.5 else { return }

        var context = context
        context.opacity = alpha
        context.translateBy(x: x, y: y)
        context.rotate(by: .radians(piece.spin * t + piece.phase))
        context.scaleBy(x: 1, y: max(0.05, abs(cos(t * piece.flip + piece.phase))))
        let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.isRound ? piece.width : piece.height)
        let path = piece.isRound ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
        context.fill(path, with: .color(colors[piece.color % colors.count]))
    }
}
