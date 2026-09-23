//
//  KitoEntitlements.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The subscription the customer is paying for right now, with its renewal details.
public struct KitoActiveSubscription: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Paid up (or in a free trial).
        case active
        /// A renewal payment failed; access continues while Apple retries.
        case gracePeriod
        /// A renewal payment failed and Apple is retrying; access may be paused.
        case billingRetry
    }

    public var productID: String
    public var purchaseDate: Date
    /// When the current period (or trial) ends.
    public var expirationDate: Date?
    public var isInTrial: Bool
    public var willAutoRenew: Bool
    /// The plan it renews into, when the customer has switched plans for the next period.
    public var renewsToProductID: String?
    public var state: State

    public init(
        productID: String,
        purchaseDate: Date = .now,
        expirationDate: Date? = nil,
        isInTrial: Bool = false,
        willAutoRenew: Bool = true,
        renewsToProductID: String? = nil,
        state: State = .active
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.isInTrial = isInTrial
        self.willAutoRenew = willAutoRenew
        self.renewsToProductID = renewsToProductID
        self.state = state
    }
}

/// One transaction, reduced to what decides access. Kept free of StoreKit so the rules are testable.
struct KitoTransactionRecord: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case subscription, nonConsumable, consumable, nonRenewing }

    var productID: String
    var kind: Kind
    var purchaseDate: Date
    var expirationDate: Date?
    var revocationDate: Date?
    var isUpgraded = false
    var isTrial = false
}

/// What the customer owns right now.
struct KitoEntitlements: Equatable, Sendable {
    var purchasedProductIDs: Set<String> = []
    var activeSubscription: KitoTransactionRecord?

    /// Grants access for every non-revoked, non-upgraded, unexpired subscription or
    /// non-consumable. Consumables never grant access. When several subscriptions are live
    /// (an upgrade that hasn't been processed yet), the one that runs longest is active.
    static func reduce(_ records: [KitoTransactionRecord], now: Date = .now) -> KitoEntitlements {
        var result = KitoEntitlements()
        for record in records {
            guard record.revocationDate == nil, !record.isUpgraded, record.kind != .consumable else { continue }
            if let expiration = record.expirationDate, expiration <= now { continue }
            result.purchasedProductIDs.insert(record.productID)
            guard record.kind == .subscription else { continue }
            let current = result.activeSubscription?.expirationDate ?? .distantPast
            if result.activeSubscription == nil || (record.expirationDate ?? .distantFuture) > current {
                result.activeSubscription = record
            }
        }
        return result
    }
}
