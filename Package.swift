// swift-tools-version: 5.9
//
//  Package.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoPaywall",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoPaywall", targets: ["KitoPaywall"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "KitoPaywall", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(
            name: "KitoPaywallTests",
            dependencies: ["KitoPaywall"],
            resources: [.copy("KitoPaywallTests.storekit")]
        ),
    ]
)
