import Foundation
import SafetyContent

/// A topic a person can choose, with its name.
struct TopicChipItem: Identifiable, Equatable {
    let topic: Topic
    let name: String
    var id: Topic { topic }
}

enum TopicCopy {

    /// The chip name, or `nil` for `general`. That tag is never a chip: it marks help open
    /// to anyone, which shows under every topic.
    static func name(_ topic: Topic) -> String? {
        switch topic {
        case .domesticAbuse: Strings.localized("topic.domesticAbuse")
        case .sexualViolence: Strings.localized("topic.sexualViolence")
        case .stalkingAndHarassment: Strings.localized("topic.stalkingAndHarassment")
        case .onlineAbuse: Strings.localized("topic.onlineAbuse")
        case .forcedMarriageAndFGM: Strings.localized("topic.forcedMarriageAndFGM")
        case .housingAndMoney: Strings.localized("topic.housingAndMoney")
        case .work: Strings.localized("topic.work")
        case .reportingAndVictimsRights: Strings.localized("topic.reportingAndVictimsRights")
        case .general: nil
        }
    }

    /// The eight chips, in order.
    static var chips: [TopicChipItem] {
        Topic.selectable.compactMap { topic in name(topic).map { TopicChipItem(topic: topic, name: $0) } }
    }

    /// Chip names by topic, for search: typing "stalking" finds help tagged Stalking &
    /// harassment, in whatever language the chips are in.
    static var names: [Topic: String] {
        Dictionary(uniqueKeysWithValues: chips.map { ($0.topic, $0.name) })
    }
}

enum NoMatchesScope: Sendable {
    /// Nothing on the screen matches.
    case everything
    /// Learn: no rights topic matches, though iPhone features may.
    case rights
}

enum FilterCopy {

    static var allOfTheUK: String { Strings.localized("filter.nation.all") }

    static func nationName(_ nation: Nation?) -> String {
        nation.map(NationCopy.name) ?? allOfTheUK
    }

    static func offer(_ nation: Nation) -> String {
        String(format: Strings.localized("filter.nation.offer"), NationCopy.name(nation))
    }

    /// On Get help and Learn, which fall back to all of the UK.
    static func problem(_ problem: NationPreference.Problem) -> String {
        switch problem {
        case .couldNotRead: Strings.localized("filter.nation.couldNotRead")
        case .couldNotSave: Strings.localized("filter.nation.couldNotSave")
        }
    }

    /// On Refuges, which needs a nation to list anything, so it says what it does instead.
    static func refugesProblem(_ problem: NationPreference.Problem) -> String {
        switch problem {
        case .couldNotRead: Strings.localized("refuges.nation.couldNotRead")
        case .couldNotSave: Strings.localized("refuges.nation.notSaved")
        }
    }

    /// The line that says what the list is narrowed to: "Showing Scotland · Stalking &
    /// harassment". `nil` when nothing is narrowed. Topics follow chip order, not the
    /// order they were tapped in, so the same filter always reads the same.
    static func summary(nation: Nation?, topics: Set<Topic>, query: String) -> String? {
        var parts: [String] = []
        if let nation { parts.append(NationCopy.name(nation)) }
        parts += Topic.selectable.filter(topics.contains).compactMap(TopicCopy.name)
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !SearchText.words(in: typed).isEmpty {
            parts.append(String(format: Strings.localized("filter.summary.search"), typed))
        }
        guard !parts.isEmpty else { return nil }
        return String(format: Strings.localized("filter.summary"), parts.joined(separator: Strings.localized("filter.summary.separator")))
    }

    /// What VoiceOver hears when the number of results changes.
    static func resultCount(_ count: Int) -> String {
        count == 0 ? Strings.localized("filter.noMatches.title") : Strings.localized("filter.resultCount \(count)")
    }

    static func noMatchesTitle(_ scope: NoMatchesScope) -> String {
        switch scope {
        case .everything: Strings.localized("filter.noMatches.title")
        case .rights: Strings.localized("filter.noMatches.rights")
        }
    }
}
