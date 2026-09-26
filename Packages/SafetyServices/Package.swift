// swift-tools-version: 6.4

import PackageDescription

// Protocols first, Apple implementations behind them. Every protocol has a double in
// SafetyTesting, which is what makes the emergency flows testable without a device
// and without contacting anyone. See ADR-0003.
let package = Package(
    name: "SafetyServices",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [.library(name: "SafetyServices", targets: ["SafetyServices"])],
    dependencies: [.package(path: "../SafetyDomain")],
    targets: [
        .target(
            name: "SafetyServices",
            dependencies: ["SafetyDomain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SafetyServicesTests",
            dependencies: ["SafetyServices"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
