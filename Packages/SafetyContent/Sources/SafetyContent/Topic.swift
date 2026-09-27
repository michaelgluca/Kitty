import Foundation

/// What an item of help is about, for the topic chips on Get help and Learn.
///
/// A fixed set, so a typo in the content pack fails to decode rather than creating a
/// topic nobody can choose. Tags are content claims, checked against the research like
/// any fact; the whole table is pinned by `TopicTagTests`. The JSON is reused verbatim
/// by the Kotlin port, and `ContentFilter` states the rules it follows.
public enum Topic: String, Codable, Sendable, CaseIterable, Hashable {
    case domesticAbuse
    case sexualViolence
    case stalkingAndHarassment
    case onlineAbuse
    case forcedMarriageAndFGM
    case housingAndMoney
    case work
    case reportingAndVictimsRights
    /// For anyone in distress, whatever is happening: Samaritans. Shown under every topic,
    /// so choosing a topic never hides it. Valid on services only (checked at load): a
    /// right or a reporting route is always about something in particular.
    case general

    /// The topics a person can choose, in the order the chips show them. `general` is not
    /// one: it is never chosen, only always included.
    public static let selectable: [Topic] = allCases.filter { $0 != .general }
}
