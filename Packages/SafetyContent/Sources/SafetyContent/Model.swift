import Foundation

/// Which part of the UK a service actually covers.
///
/// Modelled explicitly because getting this wrong is a real harm. The National
/// Domestic Abuse Helpline covers England; Wales, Scotland and Northern Ireland each
/// run their own. British Transport Police covers Great Britain, not the UK —
/// Northern Ireland is excluded. The Met covers London, not England.
///
/// Where an operator does not state its coverage, `SupportService.coverage` is `nil`
/// and no label is shown. Presenting a nation the operator has not claimed would be
/// inventing a fact.
public enum Coverage: String, Codable, Sendable, CaseIterable {
    case unitedKingdom
    case greatBritain
    case england
    case englandAndWales
    case wales
    case scotland
    case northernIreland
    case london
}

public enum ServiceKind: String, Codable, Sendable {
    case helpline
    case charity
    case information
    case reporting
}

public enum DaySet: String, Codable, Sendable {
    case weekdays
    case weekends
    case everyDay

    /// `day` is a Calendar weekday number, where 1 is Sunday and 7 is Saturday.
    func contains(calendarWeekday day: Int) -> Bool {
        switch self {
        case .weekdays: (2...6).contains(day)
        case .weekends: day == 1 || day == 7
        case .everyDay: (1...7).contains(day)
        }
    }
}

/// One span of opening hours on a set of days, in UK local time.
///
/// `closeHour` is exclusive and may be 24, meaning "until midnight". Windows that
/// cross midnight are deliberately not supported: no service in the pack needs one,
/// and a half-supported case is worse than a clearly rejected one.
public struct OpeningWindow: Codable, Sendable, Equatable {
    public let days: DaySet
    public let openHour: Int
    public let closeHour: Int

    public init(days: DaySet, openHour: Int, closeHour: Int) {
        self.days = days
        self.openHour = openHour
        self.closeHour = closeHour
    }

    var isPlausible: Bool {
        (0...23).contains(openHour) && (1...24).contains(closeHour) && openHour < closeHour
    }
}

/// When a service can actually be reached.
///
/// A user in crisis at 2am who taps a service that is shut has been failed. Hours are
/// data rather than prose so the UI can show a closed state instead of a dead end.
public enum Availability: Sendable, Equatable {
    case allHours
    /// Hours too irregular to model honestly — Galop's, for example, change by day,
    /// close for lunch and close early on the first Thursday of the month. Shown as
    /// "check their website" rather than flattened into something wrong.
    case seeWebsite
    case schedule([OpeningWindow])
}

// Hand-written so the JSON reads naturally and so implausible hours fail loudly at
// load time. A typo such as openHour 17, closeHour 7 would otherwise make a line read
// as permanently closed — a silent content error with real consequences.
extension Availability: Codable {
    private enum Keys: String, CodingKey { case schedule }

    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(String.self) {
            switch raw {
            case "allHours": self = .allHours
            case "seeWebsite": self = .seeWebsite
            default:
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unknown availability \"\(raw)\"")
            }
            return
        }
        let keyed = try decoder.container(keyedBy: Keys.self)
        let windows = try keyed.decode([OpeningWindow].self, forKey: .schedule)
        guard !windows.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .schedule, in: keyed, debugDescription: "A schedule needs at least one window")
        }
        guard windows.allSatisfy(\.isPlausible) else {
            throw DecodingError.dataCorruptedError(forKey: .schedule, in: keyed, debugDescription: "Implausible opening hours")
        }
        self = .schedule(windows)
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .allHours:
            var c = encoder.singleValueContainer(); try c.encode("allHours")
        case .seeWebsite:
            var c = encoder.singleValueContainer(); try c.encode("seeWebsite")
        case let .schedule(windows):
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(windows, forKey: .schedule)
        }
    }
}

public struct SupportService: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let kind: ServiceKind
    /// `nil` when the operator does not state its coverage. No label is shown.
    public let coverage: Coverage?
    /// Who the service is for, where it is restricted — "Women", "Aged 18 and over".
    /// Shown so nobody is sent to a line that will turn them away.
    public let audience: String?
    public let summary: String
    /// A VOICE number, written as the operator publishes it ("0808 2000 247") so it
    /// is readable under stress and can be dialled by hand. Absent when the service
    /// has no telephone line — Women's Aid runs none.
    ///
    /// Never a text-only destination. A text number in this field would be rendered
    /// as a call button: a "Text 999" card carrying 999 here would place a VOICE call
    /// for someone who cannot speak.
    public let phone: String?
    public let url: String
    public let availability: Availability
    /// Stated only when the operator itself says so — for example, that a call does
    /// not appear on an itemised bill. Never inferred from a freephone prefix.
    public let billingNote: String?
    /// The operator's own page this entry was verified against.
    public let source: String
    public let attribution: String?
}

/// One of the ways to reach 999 in the UK.
///
/// Deliberately has no dialable number. These are explanations of routes, and a
/// route such as text-to-999 must never be rendered as a call button.
public struct EmergencyRoute: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let detail: String
    /// Set when the route needs something done in advance — text-to-999 requires
    /// registration, and an app cannot register the user or verify that they did.
    public let prerequisite: String?
    public let learnMoreURL: String?
}

/// An Apple safety feature worth setting up before it is needed.
public struct SafetyGuide: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let summary: String
    /// A trade-off the user must understand before switching the feature on. Medical
    /// ID's "Show When Locked", for instance, lets anyone holding the phone read the
    /// named emergency contacts without the passcode.
    public let caution: String?
    public let url: String
}

public struct ContentPack: Codable, Sendable, Equatable {
    public let version: Int
    public let reviewedOn: String
    public let emergencyRoutes: [EmergencyRoute]
    public let services: [SupportService]
    public let guides: [SafetyGuide]
}
