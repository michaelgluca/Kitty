import Foundation

/// Whether the app should present its UK services layer.
///
/// The app is available worldwide but its safety content is written for the UK. The
/// alert and trusted-contact features are country-neutral — they send the user's own
/// data through the user's own Messages to the user's own contacts — so only the
/// services layer needs fencing.
public enum RegionStance: Sendable, Equatable {
    /// Show UK services.
    case unitedKingdom
    /// Show the non-UK notice. The country code is whatever we could infer, which may
    /// be nothing.
    case elsewhere(countryCode: String?)

    public var isUnitedKingdom: Bool {
        if case .unitedKingdom = self { return true }
        return false
    }
}

/// Signals available without any permission and without any network call.
///
/// Deliberately no CoreLocation: knowing which helplines to show is not worth a
/// location prompt, and a user who declines it must not lose the content.
public struct RegionSignals: Sendable, Equatable {
    /// `Locale.autoupdatingCurrent.region?.identifier` — the device region setting.
    public var deviceRegion: String?
    /// The App Store storefront, which StoreKit reports as an alpha-3 code such as
    /// `GBR`. Optional because it is read asynchronously and may never arrive.
    public var storefrontCode: String?
    /// An explicit choice in Settings. Always wins.
    public var userOverride: RegionStance?

    public init(deviceRegion: String? = nil, storefrontCode: String? = nil, userOverride: RegionStance? = nil) {
        self.deviceRegion = deviceRegion
        self.storefrontCode = storefrontCode
        self.userOverride = userOverride
    }
}

public enum RegionResolver {

    /// Resolve which services layer to show.
    ///
    /// The rule is deliberately biased toward the UK: if *either* signal says Great
    /// Britain, UK content is shown. Wrongly showing Refuge to someone who is not in
    /// the UK is harmless — they can ignore it. Wrongly hiding it from someone who
    /// is, because their phone is set to `en_US`, is not.
    public static func resolve(_ signals: RegionSignals) -> RegionStance {
        if let override = signals.userOverride { return override }

        let device = normalise(signals.deviceRegion)
        let storefront = normalise(signals.storefrontCode)

        if device == "GB" || storefront == "GB" { return .unitedKingdom }
        return .elsewhere(countryCode: device ?? storefront)
    }

    /// Accepts alpha-2 and alpha-3, because the device region reports `GB` while the
    /// App Store storefront reports `GBR`.
    static func normalise(_ code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        let upper = code.uppercased()
        switch upper {
        case "GBR": return "GB"
        // The UK's constituent-country and dependency codes are not GB, but a user
        // there needs UK services. `UK` is not an ISO code at all, yet it appears in
        // the wild often enough to be worth accepting.
        case "UK": return "GB"
        default: return upper
        }
    }
}
