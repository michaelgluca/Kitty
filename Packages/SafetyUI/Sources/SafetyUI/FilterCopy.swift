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
        key(topic).map { Strings.localized(String.LocalizationValue($0)) }
    }

    /// The eight chips, in order.
    static var chips: [TopicChipItem] {
        Topic.selectable.compactMap { topic in name(topic).map { TopicChipItem(topic: topic, name: $0) } }
    }

    /// What search finds each topic by, in whatever language the chips are in: its chip
    /// name, so "stalking" finds help tagged Stalking & harassment, and the other words
    /// people use for it, so "domestic violence" finds every domestic abuse helpline
    /// whether or not its own entry says "violence".
    static var searchTerms: [Topic: [String]] {
        Dictionary(uniqueKeysWithValues: Topic.selectable.compactMap { topic in
            key(topic).map { key in
                (topic, [key, "\(key).searchTerms"].map { Strings.localized(String.LocalizationValue($0)) })
            }
        })
    }

    private static func key(_ topic: Topic) -> String? {
        switch topic {
        case .domesticAbuse: "topic.domesticAbuse"
        case .sexualViolence: "topic.sexualViolence"
        case .stalkingAndHarassment: "topic.stalkingAndHarassment"
        case .onlineAbuse: "topic.onlineAbuse"
        case .forcedMarriageAndFGM: "topic.forcedMarriageAndFGM"
        case .housingAndMoney: "topic.housingAndMoney"
        case .work: "topic.work"
        case .reportingAndVictimsRights: "topic.reportingAndVictimsRights"
        case .general: nil
        }
    }
}

enum NoMatchesScope: Sendable {
    /// Nothing on the screen matches.
    case everything
    /// Learn: no rights topic matches, though iPhone features may.
    case rights
    /// The iPhone features screen: search only, with no nation menu or topic chips to
    /// mention clearing.
    case features
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
    /// Only for a save failure whose pick is the one Refuges is actually showing —
    /// otherwise use `refugesCouldNotSaveElsewhere`, which claims nothing about what is
    /// on screen.
    static func refugesProblem(_ problem: NationPreference.Problem) -> String {
        switch problem {
        case .couldNotRead: Strings.localized("refuges.nation.couldNotRead")
        case .couldNotSave: Strings.localized("refuges.nation.notSaved")
        }
    }

    /// A save failure whose pick — a nation, or "all of the UK" itself — is not the one
    /// Refuges is showing: naming it here would misattribute somebody else's screen, or a
    /// choice that was never a nation to begin with, to this one.
    static var refugesCouldNotSaveElsewhere: String { Strings.localized("refuges.nation.couldNotSaveElsewhere") }

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
        case .everything, .features: Strings.localized("filter.noMatches.title")
        case .rights: Strings.localized("filter.noMatches.rights")
        }
    }

    /// The line under the title. Different on the iPhone features screen: it has no
    /// nation menu or topic chips, so the line that tells you to clear them would be
    /// describing controls that are not there.
    static func noMatchesBody(_ scope: NoMatchesScope) -> String {
        switch scope {
        case .everything, .rights: Strings.localized("filter.noMatches.body")
        case .features: Strings.localized("filter.noMatches.features.body")
        }
    }
}
