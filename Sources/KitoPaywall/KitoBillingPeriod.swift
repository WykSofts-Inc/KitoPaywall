//
//  KitoBillingPeriod.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import StoreKit

/// How often a subscription renews, or how long a free trial lasts: `value` × `unit`.
public struct KitoBillingPeriod: Hashable, Sendable, CustomStringConvertible {
    public enum Unit: Hashable, Sendable, CaseIterable {
        case day, week, month, year

        /// Weeks in one of this unit. A year is 52 weeks and a month a twelfth of that, the
        /// convention paywalls use for "per week" prices.
        var weeks: Decimal {
            switch self {
            case .day: return Decimal(1) / Decimal(7)
            case .week: return 1
            case .month: return Decimal(52) / Decimal(12)
            case .year: return 52
            }
        }

        var calendarComponent: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }

        /// "day", "week", "month", "year".
        public var name: String {
            switch self {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            case .year: return "year"
            }
        }
    }

    public var value: Int
    public var unit: Unit

    public init(_ value: Int, _ unit: Unit) {
        self.value = max(1, value)
        self.unit = unit
    }

    public static let weekly = KitoBillingPeriod(1, .week)
    public static let monthly = KitoBillingPeriod(1, .month)
    public static let quarterly = KitoBillingPeriod(3, .month)
    public static let yearly = KitoBillingPeriod(1, .year)

    /// A free trial or period of `days` days. Multiples of seven become weeks.
    public static func days(_ days: Int) -> KitoBillingPeriod {
        days > 0 && days % 7 == 0 ? KitoBillingPeriod(days / 7, .week) : KitoBillingPeriod(days, .day)
    }

    /// The period's length in weeks (52 to the year).
    public var weeks: Decimal { Decimal(value) * unit.weeks }

    /// Whole days, for trial copy: a week is 7, a month 30, a year 365.
    public var approximateDays: Int {
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        }
    }

    /// "week", "3 months".
    public var description: String {
        value == 1 ? unit.name : "\(value) \(unit.name)s"
    }

    /// "Weekly", "Monthly", "Yearly", or "3 Months".
    public var adjective: String {
        guard value == 1 else { return "\(value) \(unit.name.capitalized)s" }
        switch unit {
        case .day: return "Daily"
        case .week: return "Weekly"
        case .month: return "Monthly"
        case .year: return "Yearly"
        }
    }

    /// Trial copy: "3-day", "7-day", "1-month", "1-year". Weeks read as days, the way people say it.
    public var trialLength: String {
        switch unit {
        case .day: return "\(value)-day"
        case .week: return "\(value * 7)-day"
        case .month: return "\(value)-month"
        case .year: return "\(value)-year"
        }
    }
}

extension KitoBillingPeriod {
    /// Converts a StoreKit subscription period, folding "7 days" into "1 week".
    public init(_ period: Product.SubscriptionPeriod) {
        switch period.unit {
        case .day: self = .days(period.value)
        case .week: self.init(period.value, .week)
        case .month: self.init(period.value, .month)
        case .year: self.init(period.value, .year)
        @unknown default: self.init(period.value, .month)
        }
    }
}
