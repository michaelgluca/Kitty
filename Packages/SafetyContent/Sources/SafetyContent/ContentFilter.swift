import Foundation

/// What a screen is narrowed to. Empty criteria match everything.
public struct FilterCriteria: Sendable, Equatable {
    /// `nil` means all of the UK.
    public var nation: Nation?
    /// Combined with OR: an item shows when it carries any of them, or `general`.
    public var topics: Set<Topic>
    /// As typed. Compared through `SearchText`.
    public var query: String

    public init(nation: Nation? = nil, topics: Set<Topic> = [], query: String = "") {
        self.nation = nation
        self.topics = topics
        self.query = query
    }

    /// The words searched for; empty when nothing searchable was typed.
    public var words: [String] { SearchText.words(in: query) }
}

/// A rights topic as shown for a nation.
public struct RightsMatch: Sendable, Equatable, Identifiable {
    public let topic: RightsTopic
    /// The points that apply in the chosen nation, or every point when none is chosen.
    public let here: [RightsPoint]
    /// The points for the other nations. Shown collapsed under "Different elsewhere in the
    /// UK": hidden until opened, never removed.
    public let elsewhere: [RightsPoint]

    public var id: String { topic.id }
}

/// Narrows the pack's help to a nation, topics and a search.
///
/// Pure: no state, no localisation, no platform types. The rules are tested on the host,
/// and the Kotlin port follows them line for line. The 999 routes are deliberately not an
/// input, so nothing here can hide them.
public enum ContentFilter {

    /// Services or reporting routes that match the nation, the topics and the search.
    ///
    /// - Parameter topicNames: the chip names in the person's language, so a search for
    ///   "stalking" finds help tagged Stalking & harassment. `general` has no name.
    public static func services(
        _ items: [SupportService], matching criteria: FilterCriteria, topicNames: [Topic: String]
    ) -> [SupportService] {
        let words = criteria.words
        return items.filter { item in
            let fields: [String?] = [item.name, item.summary, item.audience] + item.topics.map { topicNames[$0] }
            return serves(item.coverage, in: criteria.nation)
                && isAbout(item.topics, criteria.topics)
                && SearchText.contains(words, in: fields)
        }
    }

    /// Rights topics with at least one point for the nation that match the topics and the
    /// search, each split into the points here and elsewhere.
    public static func rights(
        _ topics: [RightsTopic], matching criteria: FilterCriteria, topicNames: [Topic: String]
    ) -> [RightsMatch] {
        let words = criteria.words
        return topics.compactMap { topic in
            let match = split(topic, for: criteria.nation)
            let fields: [String?] = [topic.title, topic.summary] + topic.topics.map { topicNames[$0] }
            guard !match.here.isEmpty,
                  isAbout(topic.topics, criteria.topics),
                  SearchText.contains(words, in: fields)
            else { return nil }
            return match
        }
    }

    /// iPhone features answer only to search. They are not specific to a nation or a
    /// topic, so neither ever hides one.
    public static func guides(_ guides: [SafetyGuide], matching criteria: FilterCriteria) -> [SafetyGuide] {
        let words = criteria.words
        return guides.filter { SearchText.contains(words, in: [$0.title, $0.summary]) }
    }

    /// The points that apply in `nation` and the rest, in their original order. With no
    /// nation, every point applies.
    public static func split(_ topic: RightsTopic, for nation: Nation?) -> RightsMatch {
        guard let nation else { return RightsMatch(topic: topic, here: topic.points, elsewhere: []) }
        return RightsMatch(
            topic: topic,
            here: topic.points.filter { $0.nations.contains(nation) },
            elsewhere: topic.points.filter { !$0.nations.contains(nation) }
        )
    }

    /// No stated coverage shows everywhere: when in doubt, show. `london` counts as
    /// England, through `Coverage.includes(_:)`.
    static func serves(_ coverage: Coverage?, in nation: Nation?) -> Bool {
        guard let nation, let coverage else { return true }
        return coverage.includes(nation)
    }

    /// Any chosen topic (OR), or `general`, which shows under every topic.
    static func isAbout(_ tags: [Topic], _ chosen: Set<Topic>) -> Bool {
        chosen.isEmpty || tags.contains(.general) || tags.contains(where: chosen.contains)
    }
}
