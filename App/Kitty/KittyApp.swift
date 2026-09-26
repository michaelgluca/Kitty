import SafetyDomain
import SafetyServices
import SafetyUI
import SwiftUI

/// The composition root.
///
/// Everything the app needs is built here and injected downward. No singletons and
/// no service locator: a view can only reach a service that was handed to it, which
/// is what keeps the emergency paths substitutable in tests. See ADR-0003.
///
/// This is a pure SwiftUI `App`, which satisfies the scene-based life cycle that
/// iOS 27 SDK builds require — an app built against that SDK without it does not
/// launch at all.
@main
struct KittyApp: App {

    private let services = Services.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.services, services)
        }
    }
}

/// The set of capabilities the app is built from.
///
/// A struct of protocol existentials rather than a container type, so the wiring is
/// visible at a glance and a test can replace exactly one thing.
struct Services: Sendable {
    var location: any LocationProviding
    var messages: any MessageComposing
    var dialler: any Dialling
    var contacts: any TrustedContactStoring
    var battery: any BatteryReading
    var time: any TimeSource

    static func live() -> Services {
        Services(
            location: UnavailableLocationProvider(),
            messages: UnavailableMessageComposer(),
            dialler: UnavailableDialler(),
            contacts: KeychainContactStore(service: Bundle.main.bundleIdentifier ?? "uk.co.example.safety"),
            battery: DeviceBattery(),
            time: SystemTimeSource()
        )
    }
}

private struct ServicesKey: EnvironmentKey {
    static let defaultValue = Services.live()
}

extension EnvironmentValues {
    var services: Services {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}
