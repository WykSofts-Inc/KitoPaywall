//
//  KitoStore.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import Observation
import StoreKit

/// StoreKit 2 in one object: loads your products, buys and restores them, listens for
/// transactions made elsewhere (Ask to Buy, renewals, other devices), finishes every verified
/// transaction and keeps `purchasedProductIDs` current.
///
/// ```swift
/// @State private var store = KitoStore(productIDs: ["pro.monthly", "pro.yearly"], mostPopular: "pro.yearly")
/// ```
///
/// Use `KitoStore.preview()` for layouts and galleries: the same API, no App Store.
@MainActor
@Observable
public final class KitoStore {
    public let productIDs: [String]
    public let mostPopular: String?

    /// Loaded products, in plan order.
    public private(set) var products: [Product] = []
    /// Loaded products as display plans, sorted, badged and trial-aware.
    public private(set) var plans: [KitoPaywallPlan] = []
    /// Products the customer owns right now: active subscriptions and non-consumables.
    public private(set) var purchasedProductIDs: Set<String> = []
    /// The live subscription, with its renewal details.
    public private(set) var activeSubscription: KitoActiveSubscription?
    public private(set) var isLoading = false
    public private(set) var hasLoaded = false
    /// The last thing that went wrong, cleared by the next successful call.
    public private(set) var lastError: KitoStoreError?

    private enum Mode { case live, preview(delay: Duration) }
    private let mode: Mode
    private var introEligibility: [String: Bool] = [:]
    @ObservationIgnored nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    /// A store for `productIDs`. It starts listening for transactions straight away; call
    /// `load()` (a paywall does this for you) to fetch the products.
    public init(productIDs: [String], mostPopular: String? = nil) {
        self.productIDs = productIDs
        self.mostPopular = mostPopular
        self.mode = .live
        updatesTask = Task { [weak self] in
            await self?.finishUnfinished()
            await self?.refreshEntitlements()
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    private init(previewPlans: [KitoPaywallPlan], mostPopular: String?, isPro: Bool, delay: Duration) {
        let arranged = KitoPaywallPlan.arranged(previewPlans, mostPopular: mostPopular)
        self.productIDs = arranged.map(\.id)
        self.mostPopular = mostPopular
        self.mode = .preview(delay: delay)
        self.plans = arranged
        self.hasLoaded = true
        if isPro, let plan = KitoPaywallPlan.defaultSelection(in: arranged) {
            grantPreview(plan)
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// A store that never talks to the App Store: purchases succeed after `purchaseDelay`, and
    /// restore finds whatever was bought. For previews, galleries and UI tests.
    public static func preview(
        plans: [KitoPaywallPlan] = KitoPaywallPlan.previewPlans,
        mostPopular: String? = nil,
        isPro: Bool = false,
        purchaseDelay: Duration = .seconds(1.2)
    ) -> KitoStore {
        KitoStore(previewPlans: plans, mostPopular: mostPopular, isPro: isPro, delay: purchaseDelay)
    }

    // MARK: Reading state

    /// True when the customer owns any of this store's products.
    public var isPro: Bool { !purchasedProductIDs.isDisjoint(with: productIDs) }

    /// True when the customer owns `productID`.
    public func isEntitled(_ productID: String) -> Bool { purchasedProductIDs.contains(productID) }

    /// True when the customer can still take `productID`'s introductory offer. Apple allows one
    /// per subscription group.
    public func isEligibleForIntroOffer(_ productID: String) -> Bool {
        if let eligible = introEligibility[productID] { return eligible }
        return plan(for: productID)?.trial != nil
    }

    public var errorMessage: String? { lastError?.errorDescription }

    public func product(for id: String) -> Product? { products.first { $0.id == id } }

    public func plan(for id: String) -> KitoPaywallPlan? { plans.first { $0.id == id } }

    // MARK: Loading

    /// Fetches the products, their trial eligibility and the customer's entitlements.
    public func load() async {
        guard case .live = mode else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: productIDs)
            products = fetched
            await refreshEligibility()
            lastError = fetched.isEmpty
                ? .productsUnavailable(missing: productIDs)
                : nil
        } catch {
            lastError = KitoStoreError(error)
        }
        hasLoaded = true
        await refreshEntitlements()
    }

    /// Re-reads `Transaction.currentEntitlements` and the active subscription's status.
    public func refreshEntitlements() async {
        guard case .live = mode else { return }
        var records: [KitoTransactionRecord] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            records.append(Self.record(for: transaction))
        }
        let entitlements = KitoEntitlements.reduce(records)
        purchasedProductIDs = entitlements.purchasedProductIDs
        if let record = entitlements.activeSubscription {
            activeSubscription = await subscription(for: record)
        } else {
            activeSubscription = nil
        }
        if !products.isEmpty { await refreshEligibility() }
    }

    // MARK: Buying

    /// Buys `plan`. Never throws: every ending is a `KitoPurchaseOutcome`, and failures also set `lastError`.
    @discardableResult
    public func purchase(_ plan: KitoPaywallPlan) async -> KitoPurchaseOutcome {
        switch mode {
        case .preview(let delay):
            lastError = nil
            try? await Task.sleep(for: delay)
            grantPreview(plan)
            return .purchased(productID: plan.id)
        case .live:
            guard let product = product(for: plan.id) else { return fail(.productNotFound(plan.id)) }
            return await purchase(product)
        }
    }

    /// Buys `product`, verifies and finishes the transaction, and refreshes entitlements.
    @discardableResult
    public func purchase(_ product: Product) async -> KitoPurchaseOutcome {
        lastError = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return fail(.failedVerification) }
                await transaction.finish()
                await refreshEntitlements()
                return .purchased(productID: transaction.productID)
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return fail(.other("The App Store returned an unexpected result. Try again."))
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            return fail(KitoStoreError(error))
        }
    }

    /// Asks the App Store for the customer's purchases (`AppStore.sync()`), which may prompt them to sign in.
    @discardableResult
    public func restore() async -> KitoRestoreOutcome {
        lastError = nil
        switch mode {
        case .preview(let delay):
            try? await Task.sleep(for: delay)
        case .live:
            do {
                try await AppStore.sync()
            } catch StoreKitError.userCancelled {
                return .cancelled
            } catch {
                let failure = KitoStoreError(error)
                lastError = failure
                return .failed(failure)
            }
            await refreshEntitlements()
        }
        return isPro ? .restored : .nothingToRestore
    }

    // MARK: Private

    private func fail(_ error: KitoStoreError) -> KitoPurchaseOutcome {
        lastError = error
        return .failed(error)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func finishUnfinished() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { await transaction.finish() }
        }
    }

    private func refreshEligibility() async {
        var byGroup: [String: Bool] = [:]
        var eligibility: [String: Bool] = [:]
        for product in products {
            guard let subscription = product.subscription else { continue }
            if let known = byGroup[subscription.subscriptionGroupID] {
                eligibility[product.id] = known
            } else {
                let eligible = await subscription.isEligibleForIntroOffer
                byGroup[subscription.subscriptionGroupID] = eligible
                eligibility[product.id] = eligible
            }
        }
        introEligibility = eligibility
        let order = productIDs
        let built = products.map { KitoPaywallPlan(product: $0, isEligibleForTrial: eligibility[$0.id] ?? true) }
        plans = KitoPaywallPlan.arranged(built, mostPopular: mostPopular)
        let planOrder = plans.map(\.id)
        products.sort { (planOrder.firstIndex(of: $0.id) ?? order.count) < (planOrder.firstIndex(of: $1.id) ?? order.count) }
    }

    private func subscription(for record: KitoTransactionRecord) async -> KitoActiveSubscription {
        var result = KitoActiveSubscription(
            productID: record.productID,
            purchaseDate: record.purchaseDate,
            expirationDate: record.expirationDate,
            isInTrial: record.isTrial
        )
        var product = product(for: record.productID)
        if product == nil {
            product = try? await Product.products(for: [record.productID]).first
        }
        guard let info = product?.subscription, let statuses = try? await info.status else { return result }
        let status = statuses.first { status in
            if case .verified(let transaction) = status.transaction { return transaction.productID == record.productID }
            return false
        } ?? statuses.first
        guard let status else { return result }
        if status.state == .inGracePeriod {
            result.state = .gracePeriod
        } else if status.state == .inBillingRetryPeriod {
            result.state = .billingRetry
        }
        if case .verified(let renewal) = status.renewalInfo {
            result.willAutoRenew = renewal.willAutoRenew
            if let next = renewal.autoRenewPreference, next != record.productID {
                result.renewsToProductID = next
            }
        }
        return result
    }

    private static func record(for transaction: Transaction) -> KitoTransactionRecord {
        let kind: KitoTransactionRecord.Kind
        if transaction.productType == .autoRenewable {
            kind = .subscription
        } else if transaction.productType == .consumable {
            kind = .consumable
        } else if transaction.productType == .nonRenewable {
            kind = .nonRenewing
        } else {
            kind = .nonConsumable
        }
        let isTrial: Bool
        if #available(iOS 17.2, *) {
            isTrial = transaction.offer?.type == .introductory && transaction.offer?.paymentMode == .freeTrial
        } else {
            isTrial = transaction.offerType == .introductory
        }
        return KitoTransactionRecord(
            productID: transaction.productID,
            kind: kind,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            isUpgraded: transaction.isUpgraded,
            isTrial: isTrial
        )
    }

    private func grantPreview(_ plan: KitoPaywallPlan) {
        purchasedProductIDs.insert(plan.id)
        guard let period = plan.period else { return }
        let term = plan.trial ?? period
        activeSubscription = KitoActiveSubscription(
            productID: plan.id,
            expirationDate: Calendar.current.date(byAdding: term.unit.calendarComponent, value: term.value, to: .now),
            isInTrial: plan.trial != nil
        )
        for index in plans.indices where !plans[index].isLifetime {
            introEligibility[plans[index].id] = false
            plans[index].trial = nil
        }
    }
}
