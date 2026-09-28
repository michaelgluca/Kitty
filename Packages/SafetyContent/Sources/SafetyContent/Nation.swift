import Foundation
import SafetyDomain

/// A UK nation.
///
/// Laws, helplines and housing duties differ between them, so anything true in one is
/// tagged with it rather than presented as UK-wide.
public enum Nation: String, Codable, Sendable, CaseIterable, Identifiable {
    case england
    case wales
    case scotland
    case northernIreland

    public var id: String { rawValue }
}

public extension Coverage {

    /// Whether a service with this coverage serves people in `nation`.
    func includes(_ nation: Nation) -> Bool {
        switch self {
        case .unitedKingdom: true
        case .greatBritain: nation != .northernIreland
        case .england, .london: nation == .england
        case .englandAndWales: nation == .england || nation == .wales
        case .wales: nation == .wales
        case .scotland: nation == .scotland
        case .northernIreland: nation == .northernIreland
        }
    }
}

public extension Nation {

    /// The nation a geocoded area is in, or `nil` when it cannot be told for certain.
    ///
    /// Reads each name in turn — the whole name, then only its last comma-separated
    /// part — and stops at the first that is exactly a nation's name. Nothing is
    /// matched inside a name: "Princess of Wales Road" is not Wales. Outside the UK,
    /// or with no country, the answer is `nil`, and the screen asks the person rather
    /// than guessing, because the helplines and the law differ by nation.
    init?(area: GeocodedArea) {
        guard area.countryCode?.uppercased() == "GB" else { return nil }
        for name in area.names {
            let lastPart = name.split(separator: ",").last.map(String.init)
            if let nation = Self.named(name) ?? lastPart.flatMap(Self.named) {
                self = nation
                return
            }
        }
        return nil
    }

    private static func named(_ text: String) -> Nation? {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "england": .england
        case "wales": .wales
        case "scotland": .scotland
        case "northern ireland": .northernIreland
        default: nil
        }
    }
}
