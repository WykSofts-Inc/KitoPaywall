//
//  KitoPaywallPlan.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import StoreKit

/// The ribbon on a plan: "Best value", "Most popular", "Save 40%" or your own words.
public enum KitoPlanBadge: Hashable, Sendable {
    case bestValue
    case mostPopular
    case save(Int)
    case custom(String)

    public var text: String {
        switch self {
        case .bestValue: return "Best value"
        case .mostPopular: return "Most popular"
        case .save(let percent): return "Save \(percent)%"
        case .custom(let text): return text
        }
    }
}

/// Everything a paywall shows about one purchasable option. Build it from a StoreKit `Product`,
/// or from plain values so layouts render in previews and galleries without App Store Connect.
public struct KitoPaywallPlan: Identifiable, Hashable, Sendable {
    /// The product identifier.
    public var id: String
    public var title: String
    public var price: Decimal
    public var currencyCode: String
    public var locale: Locale
    /// The localized price, e.g. "$59.99" or "KES 429.00".
    public var displayPrice: String
    /// How often it renews. `nil` for a one-time (lifetime) purchase.
    public var period: KitoBillingPeriod?
    /// The free trial, when the customer is eligible for one.
    public var trial: KitoBillingPeriod?
    public var badge: KitoPlanBadge?
    /// How much cheaper than the reference plan (usually monthly) this plan is, per week.
    /// Filled in by `arranged(_:mostPopular:)`.
    public var savingsPercent: Int?

    /// A plan from plain values, for previews and offline layouts.
    public init(
        id: String,
        title: String? = nil,
        price: Decimal,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US"),
        period: KitoBillingPeriod?,
        trial: KitoBillingPeriod? = nil,
        badge: KitoPlanBadge? = nil
    ) {
        self.id = id
        self.title = title ?? period?.adjective ?? "Lifetime"
        self.price = price
        self.currencyCode = currencyCode
        self.locale = locale
        self.displayPrice = Self.format(price, currencyCode: currencyCode, locale: locale)
        self.period = period
        self.trial = trial
        self.badge = badge
    }

    /// A plan from a StoreKit product. Pass `isEligibleForTrial: false` to hide an introductory
    /// free trial the customer has already used (`KitoStore` does this for you).
    public init(product: Product, title: String? = nil, badge: KitoPlanBadge? = nil, isEligibleForTrial: Bool = true) {
        let style = product.priceFormatStyle
        self.id = product.id
        self.price = product.price
        self.currencyCode = style.currencyCode
        self.locale = style.locale
        self.displayPrice = product.displayPrice
        self.period = product.subscription.map { KitoBillingPeriod($0.subscriptionPeriod) }
        self.badge = badge
        if isEligibleForTrial, let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            let base = KitoBillingPeriod(offer.period)
            self.trial = KitoBillingPeriod(base.value * max(1, offer.periodCount), base.unit)
        } else {
            self.trial = nil
        }
        let name = product.displayName.trimmingCharacters(in: .whitespaces)
        self.title = title ?? (name.isEmpty ? (period?.adjective ?? "Lifetime") : name)
    }

    // MARK: Derived copy

    /// A one-time purchase that never renews.
    public var isLifetime: Bool { period == nil }

    /// "year", "month", "3 months" or "lifetime".
    public var periodText: String { period?.description ?? "lifetime" }

    /// "$59.99/year", or "$149.99 once" for lifetime.
    public var priceWithPeriod: String {
        guard let period else { return "\(displayPrice) once" }
        return "\(displayPrice)/\(period.description)"
    }

    /// The price spread over one `unit`, e.g. "$1.15" per week. `nil` for lifetime plans.
    public func price(per unit: KitoBillingPeriod.Unit) -> String? {
        guard let amount = amount(per: unit) else { return nil }
        return format(amount)
    }

    /// "$1.15/week". `nil` for lifetime plans.
    public var pricePerWeekText: String? { price(per: .week).map { "\($0)/week" } }

    /// "$5.00/month". `nil` for lifetime plans.
    public var pricePerMonthText: String? { price(per: .month).map { "\($0)/month" } }

    /// "7-day free trial", or `nil` without a trial.
    public var trialText: String? { trial.map { "\($0.trialLength) free trial" } }

    /// One line under the plan title: the trial, the weekly price, or "Pay once, yours forever".
    public var summary: String {
        if isLifetime { return "Pay once, yours forever" }
        let perWeek: String?
        if let period, period.unit == .week, period.value == 1 {
            perWeek = nil
        } else {
            perWeek = pricePerWeekText
        }
        return [trialText, perWeek].compactMap { $0 }.joined(separator: " · ")
    }

    /// The small print for the purchase button: what happens, and when money moves.
    public var terms: String {
        guard let period else { return "One payment of \(displayPrice). Yours forever." }
        if let trial {
            return "Free for \(trial.approximateDays) days, then \(displayPrice)/\(period.description). Cancel anytime."
        }
        return "\(displayPrice)/\(period.description). Renews automatically, cancel anytime."
    }

    /// How much less this plan costs per week than `other`, rounded to the nearest percent.
    /// `nil` when it isn't cheaper, or either plan is lifetime.
    public func savingsPercent(comparedTo other: KitoPaywallPlan) -> Int? {
        guard let mine = amount(per: .week), let theirs = other.amount(per: .week), theirs > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: mine / theirs).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded())
        return percent > 0 ? percent : nil
    }

    // MARK: Ordering and badges

    /// Plans in the order a paywall shows them, shortest period first and lifetime last, with
    /// `savingsPercent` measured against the monthly plan (or the shortest one when there's no
    /// monthly). Badges you set are kept; otherwise `mostPopular` gets "Most popular" and the
    /// cheapest plan per week gets "Best value".
    public static func arranged(_ plans: [KitoPaywallPlan], mostPopular: String? = nil) -> [KitoPaywallPlan] {
        var sorted = plans.sorted { lhs, rhs in
            switch (lhs.period, rhs.period) {
            case (nil, nil): return lhs.price < rhs.price
            case (nil, _): return false
            case (_, nil): return true
            case (let a?, let b?): return a.weeks == b.weeks ? lhs.price < rhs.price : a.weeks < b.weeks
            }
        }
        let recurring = sorted.filter { !$0.isLifetime }
        let reference = recurring.first { $0.period == .monthly } ?? recurring.first
        if let reference {
            for index in sorted.indices where sorted[index].id != reference.id {
                guard let period = sorted[index].period, let base = reference.period, period.weeks > base.weeks else { continue }
                sorted[index].savingsPercent = sorted[index].savingsPercent(comparedTo: reference)
            }
        }
        if let mostPopular, let index = sorted.firstIndex(where: { $0.id == mostPopular }), sorted[index].badge == nil {
            sorted[index].badge = .mostPopular
        }
        let bestValue = sorted.indices
            .filter { sorted[$0].savingsPercent != nil }
            .min { (sorted[$0].amount(per: .week) ?? 0) < (sorted[$1].amount(per: .week) ?? 0) }
        if let bestValue, sorted[bestValue].badge == nil, !sorted.contains(where: { $0.badge == .bestValue }) {
            sorted[bestValue].badge = .bestValue
        }
        return sorted
    }

    /// The plan to preselect: "Most popular", then "Best value", then the first plan.
    public static func defaultSelection(in plans: [KitoPaywallPlan]) -> KitoPaywallPlan? {
        plans.first { $0.badge == .mostPopular } ?? plans.first { $0.badge == .bestValue } ?? plans.first
    }

    /// When the trial on this plan reminds and charges, starting `start`. `nil` without a trial.
    public func trialTimeline(startingAt start: Date = .now, reminderDaysBefore: Int = 2, calendar: Calendar = .current) -> KitoTrialTimeline? {
        trial.map { KitoTrialTimeline(start: start, trial: $0, reminderDaysBefore: reminderDaysBefore, calendar: calendar) }
    }

    // MARK: Private

    func amount(per unit: KitoBillingPeriod.Unit) -> Decimal? {
        guard let period, period.weeks > 0 else { return nil }
        return price / period.weeks * unit.weeks
    }

    func format(_ amount: Decimal) -> String {
        Self.format(amount, currencyCode: currencyCode, locale: locale)
    }

    static func format(_ amount: Decimal, currencyCode: String, locale: Locale) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }
}

public extension KitoPaywallPlan {
    /// Weekly, monthly (7-day trial), yearly (7-day trial) and lifetime plans in US dollars, for
    /// previews, galleries and `KitoStore.preview(plans:)`.
    static let previewPlans: [KitoPaywallPlan] = arranged([
        KitoPaywallPlan(id: "preview.weekly", price: 4.99, period: .weekly),
        KitoPaywallPlan(id: "preview.monthly", price: 9.99, period: .monthly, trial: .weekly),
        KitoPaywallPlan(id: "preview.yearly", price: 59.99, period: .yearly, trial: .weekly),
        KitoPaywallPlan(id: "preview.lifetime", price: 149.99, period: nil),
    ], mostPopular: "preview.yearly")
}
