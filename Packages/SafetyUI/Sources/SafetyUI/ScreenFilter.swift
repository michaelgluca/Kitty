import Foundation
import Observation
import SafetyContent
import SafetyDomain

/// One screen's topics and search, owned by that screen as `@State`.
///
/// Only the nation is shared and remembered (`NationPreference`). Topics and search start
/// empty each launch, as the spec keeps them out of scope for remembering.
@MainActor
@Observable
final class ScreenFilter {

    var topics: Set<Topic> = []
    var query = ""

    func toggle(_ topic: Topic) {
        if topics.contains(topic) {
            topics.remove(topic)
        } else {
            topics.insert(topic)
        }
    }

    /// Resets the topics and the search. The nation is not this model's to clear: it
    /// stays chosen, and one tap in the nation menu sets all of the UK.
    func clear() {
        topics = []
        query = ""
    }

    /// Whether Clear would change anything.
    var canClear: Bool { !topics.isEmpty || !SearchText.words(in: query).isEmpty }

    func criteria(nation: Nation?) -> FilterCriteria {
        FilterCriteria(nation: nation, topics: topics, query: query)
    }
}

/// What Get help shows for a pack, a region and a filter.
///
/// The 999 routes are copied straight from the pack and never pass through the filter:
/// whatever the nation, topics or search, every way to reach 999 is on screen.
struct HelpContent: Equatable {

    let emergencyRoutes: [EmergencyRoute]
    let services: [SupportService]
    /// Read through the UK gate first (Guideline 1.7), then filtered.
    let reporting: [SupportService]

    init(pack: ContentPack, region: RegionStance, criteria: FilterCriteria, topicNames: [Topic: String]) {
        emergencyRoutes = pack.emergencyRoutes
        services = ContentFilter.services(pack.services, matching: criteria, topicNames: topicNames)
        reporting = ContentFilter.services(pack.reporting(for: region), matching: criteria, topicNames: topicNames)
    }

    /// Whether the filter left nothing below the 999 routes. The 999 routes do not count:
    /// they are always there, so counting them would mean the screen is never "empty",
    /// and the no-matches state, with its Clear button, would never appear.
    var hasNoMatches: Bool { services.isEmpty && reporting.isEmpty }

    var resultCount: Int { services.count + reporting.count }
}

/// What Learn shows for a pack and a filter.
struct LearnContent: Equatable {

    let rights: [RightsMatch]
    /// Search only: iPhone features are the same in every nation and for every topic.
    let guides: [SafetyGuide]

    init(pack: ContentPack, criteria: FilterCriteria, topicNames: [Topic: String]) {
        rights = ContentFilter.rights(pack.rights, matching: criteria, topicNames: topicNames)
        guides = ContentFilter.guides(pack.guides, matching: criteria)
    }

    var hasNoMatches: Bool { rights.isEmpty && guides.isEmpty }

    var resultCount: Int { rights.count + guides.count }
}
