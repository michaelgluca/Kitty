// swift-tools-version: 6.4

import PackageDescription

// UK content as structured data rather than Swift literals, so it is reviewable as
// data, checkable by CI, and reusable verbatim by the later Kotlin port. See ADR-0003.
let package = Package(
    name: "SafetyContent",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [.library(name: "SafetyContent", targets: ["SafetyContent"])],
    dependencies: [.package(path: "../SafetyDomain")],
    targets: [
        .target(
            name: "SafetyContent",
            dependencies: ["SafetyDomain"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SafetyContentTests",
            dependencies: ["SafetyContent"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
