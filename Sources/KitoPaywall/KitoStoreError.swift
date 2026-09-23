//
//  KitoStoreError.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import StoreKit

/// Why a load, purchase or restore didn't go through, in words you can show the customer.
public enum KitoStoreError: Error, Equatable, Sendable, LocalizedError {
    /// The App Store returned none of the requested products.
    case productsUnavailable(missing: [String])
    /// A plan was bought that the store hasn't loaded.
    case productNotFound(String)
    /// The App Store's signature on the transaction didn't check out, so nothing was unlocked.
    case failedVerification
    /// Screen Time or device management blocks purchases.
    case purchasesNotAllowed
    case networkUnavailable
    case notAvailableInStorefront
    case other(String)

    public var errorDescription: String? {
        switch self {
        case .productsUnavailable(let missing):
            let list = missing.isEmpty ? "the products" : missing.joined(separator: ", ")
            return "The App Store didn't return \(list). Check the product IDs in App Store Connect, or attach a StoreKit configuration file to the scheme's Run action."
        case .productNotFound(let id):
            return "\u{201C}\(id)\u{201D} isn't available right now. Try again in a moment."
        case .failedVerification:
            return "This purchase couldn't be verified, so it wasn't unlocked. Try Restore purchases, or contact support."
        case .purchasesNotAllowed:
            return "Purchases are turned off on this device. Check Screen Time or your device management settings."
        case .networkUnavailable:
            return "You're offline. Check your connection and try again."
        case .notAvailableInStorefront:
            return "This plan isn't sold in your country or region."
        case .other(let message):
            return message
        }
    }

    init(_ error: Error) {
        if let error = error as? KitoStoreError {
            self = error
        } else if let error = error as? StoreKitError {
            switch error {
            case .networkError: self = .networkUnavailable
            case .notAvailableInStorefront: self = .notAvailableInStorefront
            case .notEntitled: self = .other("This Apple Account doesn't own that purchase.")
            case .unsupported: self = .other("In-app purchases aren't supported on this device.")
            case .systemError(let underlying): self = .other(underlying.localizedDescription)
            case .userCancelled: self = .other("The purchase was cancelled.")
            case .unknown: self = .other("The App Store ran into a problem. Try again in a moment.")
            default: self = .other(error.localizedDescription)
            }
        } else if let error = error as? Product.PurchaseError {
            switch error {
            case .purchaseNotAllowed: self = .purchasesNotAllowed
            case .productUnavailable: self = .notAvailableInStorefront
            case .ineligibleForOffer: self = .other("This offer isn't available on your account.")
            default: self = .other(error.localizedDescription)
            }
        } else if (error as? URLError) != nil {
            self = .networkUnavailable
        } else {
            self = .other(error.localizedDescription)
        }
    }
}

/// How a purchase ended.
public enum KitoPurchaseOutcome: Equatable, Sendable {
    /// Verified, finished and unlocked.
    case purchased(productID: String)
    /// Waiting on Ask to Buy or a payment method update. It unlocks later, through `Transaction.updates`.
    case pending
    case cancelled
    case failed(KitoStoreError)
}

/// How a restore ended.
public enum KitoRestoreOutcome: Equatable, Sendable {
    /// At least one purchase is active again.
    case restored
    case nothingToRestore
    case cancelled
    case failed(KitoStoreError)
}
