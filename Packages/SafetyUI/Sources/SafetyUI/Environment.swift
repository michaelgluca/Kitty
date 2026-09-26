import SafetyDomain
import SafetyServices
import SwiftUI

private struct ServicesKey: EnvironmentKey {
    /// Defaults to everything reporting unavailable rather than to a set of silent
    /// no-ops, so a view that never received real services fails visibly instead of
    /// appearing to work.
    static let defaultValue: Services = .unavailable
}

public extension EnvironmentValues {
    var services: Services {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}

private struct RegionStanceKey: EnvironmentKey {
    /// Defaults to the non-UK stance. Claiming the UK without evidence would show
    /// 999 and English helplines to someone who could be anywhere.
    static let defaultValue: RegionStance = .elsewhere(countryCode: nil)
}

public extension EnvironmentValues {
    var regionStance: RegionStance {
        get { self[RegionStanceKey.self] }
        set { self[RegionStanceKey.self] = newValue }
    }
}
