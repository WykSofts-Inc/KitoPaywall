//
//  KitoPaywallPlanTests.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoPaywall

/// Prices as exact decimals: `cents(999)` is 9.99.
private func cents(_ value: Int) -> Decimal { Decimal(value) / 100 }

/// ICU puts a no-break space between an ISO code and the amount; compare with plain spaces.
private func plain(_ text: String?) -> String? { text?.replacingOccurrences(of: "\u{00A0}", with: " ") }

private let us = Locale(identifier: "en_US")

final class KitoPaywallPlanTests: XCTestCase {
    private let weekly = KitoPaywallPlan(id: "weekly", price: cents(499), locale: us, period: .weekly)
    private let monthly = KitoPaywallPlan(id: "monthly", price: cents(999), locale: us, period: .monthly, trial: .weekly)
    private let yearly = KitoPaywallPlan(id: "yearly", price: cents(5999), locale: us, period: .yearly, trial: .weekly)
    private let lifetime = KitoPaywallPlan(id: "lifetime", price: cents(14999), locale: us, period: nil)

    // MARK: Price per period

    func testYearlyShillingsPerWeek() {
        let plan = KitoPaywallPlan(id: "ke.yearly", price: 429, currencyCode: "KES", locale: us, period: .yearly)
        XCTAssertEqual(plain(plan.pricePerWeekText), "KES 8.25/week")
        XCTAssertEqual(plain(plan.displayPrice), "KES 429.00")
    }

    func testYearlyDollarsPerWeekAndMonth() {
        XCTAssertEqual(yearly.pricePerWeekText, "$1.15/week")
        XCTAssertEqual(yearly.pricePerMonthText, "$5.00/month")
    }

    func testMonthlyPerWeekUsesFiftyTwoWeeksAYear() {
        // 9.99 × 12 ÷ 52 = 2.305…
        XCTAssertEqual(monthly.pricePerWeekText, "$2.31/week")
        XCTAssertEqual(monthly.pricePerMonthText, "$9.99/month")
    }

    func testWeeklyPerWeekIsItsOwnPrice() {
        XCTAssertEqual(weekly.pricePerWeekText, "$4.99/week")
    }

    func testQuarterlyPerMonth() {
        let quarterly = KitoPaywallPlan(id: "q", price: 27, locale: us, period: .quarterly)
        XCTAssertEqual(quarterly.pricePerMonthText, "$9.00/month")
    }

    func testLifetimeHasNoPerPeriodPrice() {
        XCTAssertNil(lifetime.pricePerWeekText)
        XCTAssertNil(lifetime.price(per: .month))
        XCTAssertTrue(lifetime.isLifetime)
        XCTAssertEqual(lifetime.priceWithPeriod, "$149.99 once")
    }

    func testPriceWithPeriod() {
        XCTAssertEqual(yearly.priceWithPeriod, "$59.99/year")
        XCTAssertEqual(KitoPaywallPlan(id: "q", price: 27, locale: us, period: .quarterly).priceWithPeriod, "$27.00/3 months")
    }

    // MARK: Savings

    func testYearlySavingsAgainstMonthly() {
        // 1 − 59.99 / (9.99 × 12) = 49.96 % → 50
        XCTAssertEqual(yearly.savingsPercent(comparedTo: monthly), 50)
    }

    func testSavingsRoundsToNearestPercent() {
        let yearly7199 = KitoPaywallPlan(id: "y", price: cents(7199), locale: us, period: .yearly)
        // 1 − 71.99 / 119.88 = 39.95 % → 40
        XCTAssertEqual(yearly7199.savingsPercent(comparedTo: monthly), 40)
    }

    func testNoSavingsWhenMoreExpensive() {
        XCTAssertNil(monthly.savingsPercent(comparedTo: yearly))
        XCTAssertNil(monthly.savingsPercent(comparedTo: monthly))
        XCTAssertNil(lifetime.savingsPercent(comparedTo: monthly))
        XCTAssertNil(yearly.savingsPercent(comparedTo: lifetime))
    }

    // MARK: Sorting and badges

    func testArrangedSortsShortestFirstAndLifetimeLast() {
        let arranged = KitoPaywallPlan.arranged([lifetime, yearly, weekly, monthly])
        XCTAssertEqual(arranged.map(\.id), ["weekly", "monthly", "yearly", "lifetime"])
    }

    func testArrangedMeasuresSavingsAgainstMonthly() {
        let arranged = KitoPaywallPlan.arranged([weekly, monthly, yearly, lifetime])
        XCTAssertEqual(arranged.first { $0.id == "yearly" }?.savingsPercent, 50)
        XCTAssertNil(arranged.first { $0.id == "weekly" }?.savingsPercent, "shorter than the reference plan")
        XCTAssertNil(arranged.first { $0.id == "monthly" }?.savingsPercent, "the reference itself")
        XCTAssertNil(arranged.first { $0.id == "lifetime" }?.savingsPercent)
    }

    func testArrangedFallsBackToShortestPlanWithoutMonthly() {
        let arranged = KitoPaywallPlan.arranged([yearly, weekly])
        // 1 − 59.99 / (4.99 × 52) = 76.9 % → 77
        XCTAssertEqual(arranged.last?.savingsPercent, 77)
    }

    func testBestValueGoesToCheapestPerWeek() {
        let arranged = KitoPaywallPlan.arranged([weekly, monthly, yearly])
        XCTAssertEqual(arranged.first { $0.badge == .bestValue }?.id, "yearly")
        XCTAssertEqual(arranged.filter { $0.badge != nil }.count, 1)
    }

    func testMostPopularWinsAndBestValueStillAssignedElsewhere() {
        let quarterly = KitoPaywallPlan(id: "quarterly", price: 24, locale: us, period: .quarterly)
        let arranged = KitoPaywallPlan.arranged([monthly, quarterly, yearly], mostPopular: "quarterly")
        XCTAssertEqual(arranged.first { $0.id == "quarterly" }?.badge, .mostPopular)
        XCTAssertEqual(arranged.first { $0.id == "yearly" }?.badge, .bestValue)
    }

    func testMostPopularOnCheapestPlanSkipsBestValue() {
        let arranged = KitoPaywallPlan.arranged([monthly, yearly], mostPopular: "yearly")
        XCTAssertEqual(arranged.last?.badge, .mostPopular)
        XCTAssertFalse(arranged.contains { $0.badge == .bestValue })
    }

    func testExplicitBadgesAreKept() {
        var custom = yearly
        custom.badge = .custom("Founder price")
        let arranged = KitoPaywallPlan.arranged([monthly, custom], mostPopular: "yearly")
        XCTAssertEqual(arranged.last?.badge, .custom("Founder price"))
    }

    func testDefaultSelectionPrefersMostPopularThenBestValue() {
        XCTAssertEqual(KitoPaywallPlan.defaultSelection(in: KitoPaywallPlan.arranged([weekly, monthly, yearly], mostPopular: "monthly"))?.id, "monthly")
        XCTAssertEqual(KitoPaywallPlan.defaultSelection(in: KitoPaywallPlan.arranged([weekly, monthly, yearly]))?.id, "yearly")
        XCTAssertEqual(KitoPaywallPlan.defaultSelection(in: [lifetime])?.id, "lifetime")
        XCTAssertNil(KitoPaywallPlan.defaultSelection(in: []))
    }

    func testBadgeText() {
        XCTAssertEqual(KitoPlanBadge.bestValue.text, "Best value")
        XCTAssertEqual(KitoPlanBadge.mostPopular.text, "Most popular")
        XCTAssertEqual(KitoPlanBadge.save(40).text, "Save 40%")
    }

    // MARK: Copy

    func testTrialCopy() {
        XCTAssertEqual(monthly.trialText, "7-day free trial")
        XCTAssertEqual(KitoPaywallPlan(id: "m", price: 5, locale: us, period: .monthly, trial: .days(3)).trialText, "3-day free trial")
        XCTAssertEqual(KitoPaywallPlan(id: "y", price: 5, locale: us, period: .yearly, trial: KitoBillingPeriod(1, .month)).trialText, "1-month free trial")
        XCTAssertNil(weekly.trialText)
    }

    func testSummaryAndTerms() {
        XCTAssertEqual(yearly.summary, "7-day free trial · $1.15/week")
        XCTAssertEqual(weekly.summary, "", "a weekly plan doesn't repeat its own price")
        XCTAssertEqual(lifetime.summary, "Pay once, yours forever")
        XCTAssertEqual(yearly.terms, "Free for 7 days, then $59.99/year. Cancel anytime.")
        XCTAssertEqual(weekly.terms, "$4.99/week. Renews automatically, cancel anytime.")
        XCTAssertEqual(lifetime.terms, "One payment of $149.99. Yours forever.")
    }

    func testDefaultTitles() {
        XCTAssertEqual(weekly.title, "Weekly")
        XCTAssertEqual(yearly.title, "Yearly")
        XCTAssertEqual(lifetime.title, "Lifetime")
        XCTAssertEqual(KitoPaywallPlan(id: "q", price: 1, period: .quarterly).title, "3 Months")
    }

    // MARK: Periods

    func testDaysFoldIntoWeeks() {
        XCTAssertEqual(KitoBillingPeriod.days(7), .weekly)
        XCTAssertEqual(KitoBillingPeriod.days(14), KitoBillingPeriod(2, .week))
        XCTAssertEqual(KitoBillingPeriod.days(3), KitoBillingPeriod(3, .day))
        XCTAssertEqual(KitoBillingPeriod.days(14).trialLength, "14-day")
    }

    func testPeriodWeeks() {
        XCTAssertEqual(KitoBillingPeriod.yearly.weeks, 52)
        XCTAssertEqual(KitoBillingPeriod(2, .week).weeks, 2)
        XCTAssertEqual(KitoBillingPeriod.yearly.description, "year")
        XCTAssertEqual(KitoBillingPeriod.quarterly.description, "3 months")
    }

    func testPreviewPlansAreArrangedAndBadged() {
        let plans = KitoPaywallPlan.previewPlans
        XCTAssertEqual(plans.map(\.period), [.weekly, .monthly, .yearly, nil])
        XCTAssertEqual(plans.first { $0.badge == .mostPopular }?.period, .yearly)
        XCTAssertEqual(plans.first { $0.period == .yearly }?.savingsPercent, 50)
    }
}
