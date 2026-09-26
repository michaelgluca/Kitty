import Foundation

/// Which nations a service actually covers.
///
/// Modelled explicitly because getting this wrong is a real harm: the National
/// Domestic Abuse Helpline covers England, and Wales, Scotland and Northern Ireland
/// each have their own primary lines. Presenting an England service as UK-wide sends
/// someone to the wrong place.
public enum Coverage: String, Codable, Sendable, CaseIterable {
    case unitedKingdom
    case england
    case englandAndWales
    case wales
    case scotland
    case northernIreland
}

public enum ServiceKind: String, Codable, Sendable {
    case helpline
    case charity
    case information
    case reporting
}

/// When a service is actually reachable.
///
/// A user in crisis at 2am who taps a service that is shut has been failed. Hours are
/// data, not prose, so the UI can show a closed state instead of a dead end.
public enum Availability: Sendable, Equatable {
    case allHours
    case weekdays(openHour: Int, closeHour: Int)
    case seeWebsite
}

// Hand-written so the JSON reads naturally: "allHours" as a bare string rather than
// the {"allHours":{}} shape Swift synthesises. Content is reviewed by people, and
// unreadable JSON is a correctness risk in a file where correctness is safety.
extension Availability: Codable {
    private enum Keys: String, CodingKey { case weekdays }
    private struct Weekdays: Codable { let openHour: Int; let closeHour: Int }

    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(String.self) {
            switch raw {
            case "allHours": self = .allHours; return
            case "seeWebsite": self = .seeWebsite; return
            default:
                throw DecodingError.dataCorruptedError(
                    in: single, debugDescription: "Unknown availability \"\(raw)\""
                )
            }
        }
        let keyed = try decoder.container(keyedBy: Keys.self)
        let w = try keyed.decode(Weekdays.self, forKey: .weekdays)
        guard (0...23).contains(w.openHour), (0...24).contains(w.closeHour), w.openHour < w.closeHour else {
            throw DecodingError.dataCorruptedError(
                forKey: .weekdays, in: keyed, debugDescription: "Implausible opening hours"
            )
        }
        self = .weekdays(openHour: w.openHour, closeHour: w.closeHour)
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .allHours:
            var c = encoder.singleValueContainer(); try c.encode("allHours")
        case .seeWebsite:
            var c = encoder.singleValueContainer(); try c.encode("seeWebsite")
        case let .weekdays(open, close):
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(Weekdays(openHour: open, closeHour: close), forKey: .weekdays)
        }
    }
}

public struct SupportService: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let kind: ServiceKind
    public let coverage: Coverage
    public let summary: String
    /// Absent when the service has no telephone line at all — Women's Aid, for
    /// example, is chat and email only. Inventing a number here would be dangerous.
    public let phone: String?
    public let url: String
    public let availability: Availability
    /// Shown verbatim where the service requires attribution.
    public let attribution: String?
}

/// One of the ways to reach 999 in the UK.
public struct EmergencyRoute: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let detail: String
    /// Set when the route needs something done in advance — text-to-999 requires
    /// registration, and an app cannot register the user or verify that they did.
    public let prerequisite: String?
    public let learnMoreURL: String?
}

public struct ContentPack: Codable, Sendable, Equatable {
    public let version: Int
    public let reviewedOn: String
    public let services: [SupportService]
    public let emergencyRoutes: [EmergencyRoute]
}
