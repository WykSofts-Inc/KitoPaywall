//
//  KitoTrialAndEntitlementTests.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoPaywall

final class KitoTrialTimelineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    func testSevenDayTrialReadsTodayDayFiveDaySeven() throws {
        let start = try date(2026, 9, 23)
        let timeline = KitoTrialTimeline(start: start, trial: .days(7), calendar: calendar)
        XCTAssertEqual(timeline.steps.map(\.kind), [.start, .reminder, .charge])
        XCTAssertEqual(timeline.steps.map(\.title), ["Today", "Day 5", "Day 7"])
        XCTAssertEqual(timeline.reminder?.date, try date(2026, 9, 28))
        XCTAssertEqual(timeline.chargeDate, try date(2026, 9, 30))
    }

    func testMonthTrialClampsToEndOfFebruary() throws {
        let timeline = KitoTrialTimeline(start: try date(2026, 1, 31), trial: KitoBillingPeriod(1, .month), calendar: calendar)
        XCTAssertEqual(timeline.chargeDate, try date(2026, 2, 28))
        XCTAssertEqual(timeline.steps.last?.day, 28)
        XCTAssertEqual(timeline.reminder?.day, 26)
    }

    func testShortTrialKeepsReminderAfterTheFirstDay() throws {
        let timeline = KitoTrialTimeline(start: try date(2026, 9, 23), trial: .days(3), calendar: calendar)
        XCTAssertEqual(timeline.steps.map(\.day), [0, 1, 3])
    }

    func testReminderThatWouldFallTodayIsDropped() throws {
        let timeline = KitoTrialTimeline(start: try date(2026, 9, 23), trial: .days(2), calendar: calendar)
        XCTAssertEqual(timeline.steps.map(\.kind), [.start, .charge])
        XCTAssertNil(timeline.reminder)
    }

    func testNoReminderWhenDisabled() throws {
        let timeline = KitoTrialTimeline(start: try date(2026, 9, 23), trial: .weekly, reminderDaysBefore: 0, calendar: calendar)
        XCTAssertEqual(timeline.steps.map(\.title), ["Today", "Day 7"])
    }

    func testDayCountingIgnoresTimeOfDay() throws {
        let lateStart = try date(2026, 9, 23, hour: 23)
        let timeline = KitoTrialTimeline(start: lateStart, trial: .weekly, calendar: calendar)
        XCTAssertEqual(timeline.steps.last?.day, 7)
    }

    func testPlanBuildsTimelineOnlyWithTrial() throws {
        let start = try date(2026, 9, 23)
        let withTrial = KitoPaywallPlan(id: "y", price: 60, period: .yearly, trial: .weekly)
        let without = KitoPaywallPlan(id: "w", price: 5, period: .weekly)
        XCTAssertEqual(withTrial.trialTimeline(startingAt: start, calendar: calendar)?.chargeDate, try date(2026, 9, 30))
        XCTAssertNil(without.trialTimeline(startingAt: start, calendar: calendar))
    }
}

final class KitoEntitlementsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private var later: Date { now.addingTimeInterval(86_400 * 30) }
    private var muchLater: Date { now.addingTimeInterval(86_400 * 365) }
    private var earlier: Date { now.addingTimeInterval(-86_400) }

    private func subscription(_ id: String, expires: Date?, revoked: Date? = nil, upgraded: Bool = false, trial: Bool = false) -> KitoTransactionRecord {
        KitoTransactionRecord(productID: id, kind: .subscription, purchaseDate: earlier, expirationDate: expires, revocationDate: revoked, isUpgraded: upgraded, isTrial: trial)
    }

    func testEmptyMeansNothingOwned() {
        let result = KitoEntitlements.reduce([], now: now)
        XCTAssertTrue(result.purchasedProductIDs.isEmpty)
        XCTAssertNil(result.activeSubscription)
    }

    func testActiveSubscriptionGrantsAccess() {
        let result = KitoEntitlements.reduce([subscription("monthly", expires: later, trial: true)], now: now)
        XCTAssertEqual(result.purchasedProductIDs, ["monthly"])
        XCTAssertEqual(result.activeSubscription?.productID, "monthly")
        XCTAssertEqual(result.activeSubscription?.isTrial, true)
    }

    func testExpiredRevokedAndUpgradedAreIgnored() {
        let result = KitoEntitlements.reduce([
            subscription("expired", expires: earlier),
            subscription("revoked", expires: later, revoked: earlier),
            subscription("upgraded", expires: later, upgraded: true),
        ], now: now)
        XCTAssertTrue(result.purchasedProductIDs.isEmpty)
        XCTAssertNil(result.activeSubscription)
    }

    func testExpiryExactlyNowHasEnded() {
        XCTAssertTrue(KitoEntitlements.reduce([subscription("monthly", expires: now)], now: now).purchasedProductIDs.isEmpty)
    }

    func testConsumablesNeverGrantAccess() {
        let coins = KitoTransactionRecord(productID: "coins", kind: .consumable, purchaseDate: earlier)
        XCTAssertTrue(KitoEntitlements.reduce([coins], now: now).purchasedProductIDs.isEmpty)
    }

    func testLifetimeGrantsAccessWithoutASubscription() {
        let lifetime = KitoTransactionRecord(productID: "lifetime", kind: .nonConsumable, purchaseDate: earlier)
        let result = KitoEntitlements.reduce([lifetime], now: now)
        XCTAssertEqual(result.purchasedProductIDs, ["lifetime"])
        XCTAssertNil(result.activeSubscription)
    }

    func testLongestRunningSubscriptionIsActive() {
        let result = KitoEntitlements.reduce([
            subscription("monthly", expires: later),
            subscription("yearly", expires: muchLater),
        ], now: now)
        XCTAssertEqual(result.purchasedProductIDs, ["monthly", "yearly"])
        XCTAssertEqual(result.activeSubscription?.productID, "yearly")
    }

    func testOrderDoesNotChangeTheActiveSubscription() {
        let result = KitoEntitlements.reduce([
            subscription("yearly", expires: muchLater),
            subscription("monthly", expires: later),
        ], now: now)
        XCTAssertEqual(result.activeSubscription?.productID, "yearly")
    }

    func testLifetimePlusSubscriptionKeepsBoth() {
        let result = KitoEntitlements.reduce([
            KitoTransactionRecord(productID: "lifetime", kind: .nonConsumable, purchaseDate: earlier),
            subscription("monthly", expires: later),
        ], now: now)
        XCTAssertEqual(result.purchasedProductIDs, ["lifetime", "monthly"])
        XCTAssertEqual(result.activeSubscription?.productID, "monthly")
    }

    func testErrorMessagesAreReadable() {
        XCTAssertEqual(KitoStoreError.networkUnavailable.errorDescription, "You're offline. Check your connection and try again.")
        XCTAssertTrue(KitoStoreError.productsUnavailable(missing: ["pro.yearly"]).errorDescription?.contains("pro.yearly") == true)
        XCTAssertEqual(KitoStoreError(URLError(.notConnectedToInternet)), .networkUnavailable)
        XCTAssertEqual(KitoStoreError(KitoStoreError.failedVerification), .failedVerification)
    }
}

@MainActor
final class KitoStorePreviewTests: XCTestCase {
    func testPreviewStartsLockedWithPlans() {
        let store = KitoStore.preview(purchaseDelay: .zero)
        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.plans.count, 4)
        XCTAssertTrue(store.hasLoaded)
        XCTAssertTrue(store.isEligibleForIntroOffer("preview.yearly"))
    }

    func testPreviewPurchaseUnlocksAndUsesTheTrial() async throws {
        let store = KitoStore.preview(purchaseDelay: .zero)
        let yearly = try XCTUnwrap(store.plan(for: "preview.yearly"))
        let outcome = await store.purchase(yearly)
        XCTAssertEqual(outcome, .purchased(productID: "preview.yearly"))
        XCTAssertTrue(store.isPro)
        XCTAssertTrue(store.isEntitled("preview.yearly"))
        XCTAssertEqual(store.activeSubscription?.isInTrial, true)
        XCTAssertFalse(store.isEligibleForIntroOffer("preview.monthly"), "one intro offer per group")
        XCTAssertNil(store.plan(for: "preview.monthly")?.trial)
    }

    func testPreviewLifetimeHasNoSubscription() async throws {
        let store = KitoStore.preview(purchaseDelay: .zero)
        let lifetime = try XCTUnwrap(store.plan(for: "preview.lifetime"))
        await store.purchase(lifetime)
        XCTAssertTrue(store.isPro)
        XCTAssertNil(store.activeSubscription)
    }

    func testPreviewRestore() async {
        let empty = KitoStore.preview(purchaseDelay: .zero)
        let nothing = await empty.restore()
        XCTAssertEqual(nothing, .nothingToRestore)
        let owner = KitoStore.preview(isPro: true, purchaseDelay: .zero)
        let restored = await owner.restore()
        XCTAssertEqual(restored, .restored)
    }
}
