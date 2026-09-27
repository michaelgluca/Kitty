import Foundation

enum NearbyCopy {

    /// Words for every state except `.idle` and `.found`, which the screen draws itself.
    static func message(for state: NearbyModel.State) -> String? {
        switch state {
        case .idle, .found: nil
        case .needsPermission: Strings.localized("nearby.state.needsPermission")
        case .locationOff: Strings.localized("nearby.state.locationOff")
        case .locationRestricted: Strings.localized("nearby.state.restricted")
        case .locationApproximate: Strings.localized("nearby.state.approximate")
        case .locating: Strings.localized("nearby.state.locating")
        case .noLocation: Strings.localized("nearby.state.noLocation")
        case .searching: Strings.localized("nearby.state.searching")
        case let .noneFound(metres): String(format: Strings.localized("nearby.state.noneFound"), distance(metres))
        case .searchFailed: Strings.localized("nearby.state.searchFailed")
        }
    }

    /// A road distance in the person's units — miles in the UK.
    static func distance(_ metres: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }

    static func walk(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }
}
