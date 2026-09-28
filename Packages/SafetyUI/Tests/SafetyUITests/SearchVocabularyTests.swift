import SafetyContent
import SafetyDomain
import Testing

@testable import SafetyUI

/// Search must find help by the words people actually type, not only by the words an
/// entry happens to use: a search that drops the right helpline while other rows still
/// match gives no sign that anything is missing. Run against the real pack and the
/// real catalogue, as a person would search.
@MainActor
@Suite("Search vocabulary")
struct SearchVocabularyTests {

    private func pack() throws -> ContentPack { try ContentLoader.loadUK() }

    private func helpIDs(_ query: String, in nation: Nation?) throws -> [String] {
        let criteria = FilterCriteria(nation: nation, query: query)
        let content = HelpContent(pack: try pack(), region: .unitedKingdom, criteria: criteria, topicTerms: TopicCopy.searchTerms)
        return (content.services + content.reporting).map(\.id)
    }

    @Test("\u{201C}Domestic violence\u{201D} finds each nation's domestic abuse helpline", arguments: [
        (Nation.england, "national-domestic-abuse-helpline"),
        (.wales, "live-fear-free"),
        (.scotland, "scotland-domestic-abuse-forced-marriage-helpline"),
        (.northernIreland, "dsa-helpline-northern-ireland"),
    ])
    func domesticViolenceFindsTheNationsHelpline(nation: Nation, helpline: String) throws {
        #expect(try helpIDs("domestic violence", in: nation).contains(helpline))
    }

    @Test("\u{201C}Domestic violence\u{201D} across the UK finds every domestic abuse line, including those whose entries never say \u{201C}violence\u{201D}")
    func domesticViolenceFindsEveryLine() throws {
        let found = Set(try helpIDs("domestic violence", in: nil))
        let expected: Set = [
            "national-domestic-abuse-helpline", "live-fear-free", "scotland-domestic-abuse-forced-marriage-helpline",
            "dsa-helpline-northern-ireland", "mens-advice-line", "womens-aid",
        ]
        #expect(expected.isSubset(of: found), "Missing: \(expected.subtracting(found).sorted())")
    }

    @Test("The law's own names find their rights topic", arguments: [
        ("coercive control", "what-counts-as-domestic-abuse"),
        ("Clare's Law", "ask-about-a-partner"),
        ("Clare\u{2019}s Law", "ask-about-a-partner"),
        ("non-molestation", "protection-orders"),
        ("cyberflashing", "online-abuse"),
    ])
    func lawNamesFindTheirTopic(query: String, topic: String) throws {
        let learn = LearnContent(pack: try pack(), criteria: FilterCriteria(query: query), topicTerms: TopicCopy.searchTerms)
        #expect(learn.rights.map(\.id).contains(topic))
    }
}
