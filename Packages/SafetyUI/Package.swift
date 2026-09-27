// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SafetyUI",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [.library(name: "SafetyUI", targets: ["SafetyUI"])],
    dependencies: [
        .package(path: "../SafetyDomain"),
        .package(path: "../SafetyContent"),
        .package(path: "../SafetyServices"),
        .package(path: "../SafetyTesting"),
    ],
    targets: [
        .target(
            name: "SafetyUI",
            dependencies: ["SafetyDomain", "SafetyContent", "SafetyServices"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SafetyUITests",
            dependencies: ["SafetyUI", .product(name: "SafetyTesting", package: "SafetyTesting")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
