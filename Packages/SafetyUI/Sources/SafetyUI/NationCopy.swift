import Foundation
import SafetyContent

enum NationCopy {

    static func name(_ nation: Nation) -> String {
        switch nation {
        case .england: Strings.localized("nation.england")
        case .wales: Strings.localized("nation.wales")
        case .scotland: Strings.localized("nation.scotland")
        case .northernIreland: Strings.localized("nation.northernIreland")
        }
    }

    /// Where a point applies. "Across the UK" only when it is true in all four —
    /// presenting an England-only rule as UK-wide is the error this exists to prevent.
    static func appliesIn(_ nations: [Nation]) -> String {
        let unique = Nation.allCases.filter(nations.contains)
        if unique.count == Nation.allCases.count { return Strings.localized("rights.appliesEverywhere") }
        return String(format: Strings.localized("rights.appliesIn"), unique.map(name).formatted(.list(type: .and)))
    }
}
