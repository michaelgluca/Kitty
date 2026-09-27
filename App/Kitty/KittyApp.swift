import SafetyContent
import SafetyDomain
import SafetyServices
import SafetyUI
import SwiftUI
import os

/// Failures loading the bundled content pack, worth knowing about without a device
/// attached. Never carries the pack's content — only that loading it failed.
private let contentLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "uk.co.example.safety",
    category: "content"
)

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

    private let services: Services
    /// Loaded once, here, with the failure logged rather than swallowed by a `try?`
    /// at every call site. `nil` only if the bundled resource is missing or
    /// malformed; every screen that needs it is handed this same value, and the
    /// Alert tab says so in place of the 999 button when it is `nil`.
    private let pack: ContentPack?

    init() {
        services = Services.live()
        pack = Self.loadContent()
    }

    private static func loadContent() -> ContentPack? {
        #if DEBUG
        // UI tests only: stands in for a pack that failed to load.
        if UITestSupport.withoutContent { return nil }
        #endif
        do {
            return try ContentLoader.loadUK()
        } catch {
            contentLogger.error("Bundled content pack failed to load.")
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services, pack: pack)
                .environment(\.regionStance, RegionDetection.current())
        }
    }
}

extension Services {
    /// The real wiring. Every capability is live; nothing is left reporting itself
    /// unavailable.
    static func live() -> Services {
        var services = Services.unavailable
        services.location = CoreLocationProvider()
        services.messages = SystemMessageComposer()
        services.picker = SystemContactPicker()
        services.settings = SystemSettingsOpener()
        services.dialler = SystemDialler()
        services.texter = SystemTextOpener()
        services.contacts = KeychainContactStore(service: contactStoreService())
        services.battery = DeviceBattery()
        services.places = MapKitPlaceSearch()
        services.routes = MapKitRouteFinder()
        services.maps = AppleMapsOpener()
        services.areas = MapKitAreaNamer()
        #if DEBUG
        UITestSupport.prepare(services.contacts)
        if UITestSupport.stubsNearby { UITestSupport.stubNearby(&services) }
        #endif
        return services
    }

    private static func contactStoreService() -> String {
        let base = Bundle.main.bundleIdentifier ?? "uk.co.example.safety"
        #if DEBUG
        // UI tests get their own Keychain item, so running them can never touch a
        // developer's real trusted contacts.
        if UITestSupport.isActive { return base + ".uitest" }
        #endif
        return base
    }
}
