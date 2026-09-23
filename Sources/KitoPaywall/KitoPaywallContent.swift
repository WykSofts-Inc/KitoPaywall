//
//  KitoPaywallContent.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The layout of a `KitoPaywall`.
public enum KitoPaywallStyle: String, CaseIterable, Sendable {
    /// Animated gradient hero, feature bullets, plan cards.
    case hero
    /// Free vs Pro feature table with ticks.
    case comparison
    /// Today → reminder → charge, so a trial feels safe to start.
    case trialTimeline
    /// Swipeable feature pages with page dots.
    case carousel
    /// One plan, one big button.
    case minimal
    /// Dark and gold, whatever the system appearance.
    case luxe
}

/// How plans are laid out for picking.
public enum KitoPlanPickerStyle: String, CaseIterable, Sendable {
    /// Full-width rows, stacked.
    case cards
    /// Side-by-side tiles.
    case chips
    /// A segmented switch with a big animated price under it.
    case toggle
}

/// How a feature is offered on the free tier, for the comparison table.
public enum KitoFeatureAvailability: Hashable, Sendable {
    case included
    case notIncluded
    /// Included with a limit, e.g. "3 a day".
    case limited(String)
}

/// One thing Pro unlocks.
public struct KitoPaywallFeature: Identifiable, Hashable, Sendable {
    public var id: String { title }
    public var title: String
    public var detail: String?
    public var symbol: String
    public var free: KitoFeatureAvailability

    public init(_ title: String, detail: String? = nil, symbol: String = "checkmark.seal.fill", free: KitoFeatureAvailability = .notIncluded) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.free = free
    }
}

/// The words, links and timings a paywall shows. Every property has a sensible default.
public struct KitoPaywallContent: Sendable {
    public var title: String
    public var subtitle: String
    /// The SF Symbol in the hero badge.
    public var symbol: String
    public var features: [KitoPaywallFeature]
    /// `nil` picks the layout's own picker.
    public var planPicker: KitoPlanPickerStyle?
    /// `nil` reads "Start 7-day free trial" or "Continue", depending on the selected plan.
    public var callToAction: String?
    public var termsURL: URL?
    public var privacyURL: URL?
    /// Seconds before the close button fades in. `0` shows it at once.
    public var closeButtonDelay: TimeInterval
    public var showsCloseButton: Bool
    public var reminderDaysBefore: Int
    public var celebrationTitle: String
    public var celebrationMessage: String
    /// Close the paywall once the celebration has played.
    public var dismissesAfterPurchase: Bool

    public init(
        title: String = "Unlock Pro",
        subtitle: String = "Everything, unlimited. Cancel anytime.",
        symbol: String = "crown.fill",
        features: [KitoPaywallFeature] = KitoPaywallContent.defaultFeatures,
        planPicker: KitoPlanPickerStyle? = nil,
        callToAction: String? = nil,
        termsURL: URL? = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
        privacyURL: URL? = nil,
        closeButtonDelay: TimeInterval = 2,
        showsCloseButton: Bool = true,
        reminderDaysBefore: Int = 2,
        celebrationTitle: String = "Welcome to Pro",
        celebrationMessage: String = "Everything is unlocked. Enjoy!",
        dismissesAfterPurchase: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.features = features
        self.planPicker = planPicker
        self.callToAction = callToAction
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.closeButtonDelay = closeButtonDelay
        self.showsCloseButton = showsCloseButton
        self.reminderDaysBefore = reminderDaysBefore
        self.celebrationTitle = celebrationTitle
        self.celebrationMessage = celebrationMessage
        self.dismissesAfterPurchase = dismissesAfterPurchase
    }

    public static let defaultFeatures: [KitoPaywallFeature] = [
        KitoPaywallFeature("Unlimited everything", detail: "No caps, no daily limits.", symbol: "infinity", free: .limited("3 a day")),
        KitoPaywallFeature("No ads", detail: "Just your content, nothing in the way.", symbol: "nosign"),
        KitoPaywallFeature("Sync across devices", detail: "iPhone, iPad and Mac, always up to date.", symbol: "arrow.triangle.2.circlepath.icloud.fill", free: .included),
        KitoPaywallFeature("Premium themes", detail: "Make it yours with exclusive looks.", symbol: "paintpalette.fill"),
        KitoPaywallFeature("Priority support", detail: "Real people, fast answers.", symbol: "bubble.left.and.bubble.right.fill"),
    ]
}
