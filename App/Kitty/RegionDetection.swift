import Foundation
import SafetyDomain

/// Works out whether to show the UK services layer, using only signals that cost no
/// permission and no network call.
///
/// Deliberately not CoreLocation: knowing which helplines to list is not worth a
/// location prompt, and a user who declines one must not lose the content.
enum RegionDetection {

    private static let overrideKey = "region.override"

    static func current() -> RegionStance {
        RegionResolver.resolve(
            RegionSignals(
                deviceRegion: Locale.autoupdatingCurrent.region?.identifier,
                // The App Store storefront is a useful second signal but is read
                // asynchronously and reports alpha-3 codes. The resolver already
                // handles both; wiring StoreKit is deferred until there is a settings
                // screen to surface the result in.
                storefrontCode: nil,
                userOverride: storedOverride()
            )
        )
    }

    /// An explicit choice always beats inference. Someone whose phone is set to
    /// `en_US` while they live in London, or who has left the UK, must be able to say so.
    static func storedOverride() -> RegionStance? {
        guard let raw = UserDefaults.standard.string(forKey: overrideKey) else { return nil }
        return raw == "GB" ? .unitedKingdom : .elsewhere(countryCode: raw)
    }

    static func setOverride(_ stance: RegionStance?) {
        switch stance {
        case .none:
            UserDefaults.standard.removeObject(forKey: overrideKey)
        case .unitedKingdom:
            UserDefaults.standard.set("GB", forKey: overrideKey)
        case let .elsewhere(code):
            UserDefaults.standard.set(code ?? "", forKey: overrideKey)
        }
    }
}
