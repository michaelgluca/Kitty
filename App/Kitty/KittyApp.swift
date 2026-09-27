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
            RootView(services: services)
                .environment(\.regionStance, RegionDetection.current())
        }
    }
}

extension Services {
    /// The real wiring. Location and the alert composer land in later milestones;
    /// until then those capabilities report themselves unavailable rather than
    /// silently doing nothing.
    static func live() -> Services {
        var services = Services.unavailable
        services.dialler = SystemDialler()
        services.texter = SystemTextOpener()
        services.contacts = KeychainContactStore(
            service: Bundle.main.bundleIdentifier ?? "uk.co.example.safety"
        )
        services.battery = DeviceBattery()
        return services
    }
}
