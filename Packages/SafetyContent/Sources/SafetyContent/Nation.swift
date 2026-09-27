import Foundation

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
