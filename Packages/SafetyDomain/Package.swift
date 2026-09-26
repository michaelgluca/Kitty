// swift-tools-version: 6.4

import PackageDescription

// SafetyDomain is the platform-neutral core: entities and rules, no UI and no
// Apple-only frameworks. See ADR-0003.
//
// It deliberately builds on Linux. That is not because the app runs there — it is
// how the "no UIKit, no SwiftUI, no MapKit, no CoreLocation" rule is enforced
// mechanically rather than by review. If someone adds `import SwiftUI` here, the
// Linux job in CI fails.
let package = Package(
    name: "SafetyDomain",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SafetyDomain", targets: ["SafetyDomain"])
    ],
    targets: [
        .target(
            name: "SafetyDomain",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SafetyDomainTests",
            dependencies: ["SafetyDomain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
