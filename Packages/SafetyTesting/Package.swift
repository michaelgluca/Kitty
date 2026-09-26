// swift-tools-version: 6.4

import PackageDescription

// Test doubles, so every emergency flow can be exercised without a device, without
// a network and without reaching a real person.
let package = Package(
    name: "SafetyTesting",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [.library(name: "SafetyTesting", targets: ["SafetyTesting"])],
    dependencies: [
        .package(path: "../SafetyDomain"),
        .package(path: "../SafetyServices"),
    ],
    targets: [
        .target(
            name: "SafetyTesting",
            dependencies: ["SafetyDomain", "SafetyServices"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
