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

    /// Shown above an earlier result while a refresh replaces it, so it is never
    /// read as current.
    static var updating: String { Strings.localized("nearby.state.updating") }

    /// Whether the "front counters keep limited hours / 999 in an emergency" note is
    /// shown. It belongs wherever a station was looked for — found or not — because
    /// the person with no station, no signal or no fix is the one who most needs the
    /// 999 line. Permission and progress states carry their own message instead.
    static func showsCounterNote(in state: NearbyModel.State) -> Bool {
        switch state {
        case .found, .noneFound, .searchFailed, .noLocation: true
        case .idle, .needsPermission, .locationOff, .locationRestricted, .locationApproximate, .locating, .searching: false
        }
    }

    /// The note's wording: 999 in the UK, the local emergency number elsewhere.
    static func counterNote(isUnitedKingdom: Bool) -> String {
        isUnitedKingdom ? Strings.localized("nearby.police.footer.uk") : Strings.localized("nearby.police.footer.elsewhere")
    }

    /// A road distance in the person's units — miles in the UK.
    static func distance(_ metres: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }

    /// Rounded up to at least a minute: a real walking route of, say, 20 seconds
    /// read as "About 0 minutes on foot" — true to the number, but not to the walk.
    static func walk(_ seconds: Double) -> String {
        Duration.seconds(max(seconds, 60)).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }
}
