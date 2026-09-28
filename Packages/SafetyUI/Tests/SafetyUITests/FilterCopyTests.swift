import Foundation
import SafetyContent
import Testing

@testable import SafetyUI

@Suite("Filter copy")
struct FilterCopyTests {

    @Test("Eight chips, in order, with their names; general is never a chip")
    func chips() {
        #expect(TopicCopy.chips.map(\.name) == [
            "Domestic abuse", "Sexual violence", "Stalking & harassment", "Online abuse",
            "Forced marriage & FGM", "Housing & money", "Work", "Reporting & victims' rights",
        ])
        #expect(TopicCopy.name(.general) == nil)
    }

    @Test("Search finds each chip by its name and its other words; general has none")
    func searchTerms() {
        #expect(TopicCopy.searchTerms[.general] == nil)
        #expect(TopicCopy.searchTerms.count == 8)
        for chip in TopicCopy.chips {
            #expect(TopicCopy.searchTerms[chip.topic]?.first == chip.name, "\(chip.topic)")
        }
        #expect(TopicCopy.searchTerms[.domesticAbuse]?.last?.contains("domestic violence") == true)
    }

    @Test("The summary names the nation, the topics in chip order, and the search")
    func summary() {
        #expect(FilterCopy.summary(nation: .scotland, topics: [.stalkingAndHarassment], query: "")
                == "Showing Scotland · Stalking & harassment")
        #expect(FilterCopy.summary(nation: nil, topics: [.work, .domesticAbuse], query: " refuge ")
                == "Showing Domestic abuse · Work · matching \u{201C}refuge\u{201D}")
        #expect(FilterCopy.summary(nation: .wales, topics: [], query: "") == "Showing Wales")
    }

    @Test("Nothing narrowed, nothing to summarise")
    func noSummary() {
        #expect(FilterCopy.summary(nation: nil, topics: [], query: "") == nil)
    }

    @Test("A query of only spaces or punctuation is not claimed as a search")
    func summaryIgnoresUnsearchableQuery() {
        #expect(FilterCopy.summary(nation: nil, topics: [], query: " & ") == nil)
    }

    @Test("The result count is announced in words, with plurals")
    func resultCount() {
        #expect(FilterCopy.resultCount(0) == "Nothing matches")
        #expect(FilterCopy.resultCount(1) == "1 result")
        #expect(FilterCopy.resultCount(6) == "6 results")
    }

    @Test("A changed count is announced only while its screen is on screen, never from a tab behind it")
    @MainActor
    func countAnnouncedOnlyWhenOnScreen() {
        #expect(ResultCountAnnouncement.announcement(for: 6, isOnScreen: true) == "6 results")
        #expect(ResultCountAnnouncement.announcement(for: 6, isOnScreen: false) == nil)
        #expect(ResultCountAnnouncement.announcement(for: 0, isOnScreen: false) == nil)
    }

    @Test("The detected-nation offer names the nation and where it came from")
    func offer() {
        #expect(FilterCopy.offer(.scotland) == "Use Scotland — detected from your location")
    }

    @Test("Store failures say what is shown instead")
    func problems() {
        #expect(FilterCopy.problem(.couldNotRead).contains("all of the UK"))
        #expect(FilterCopy.problem(.couldNotSave).contains("all of the UK"))
        #expect(FilterCopy.refugesProblem(.couldNotSave).contains("this screen only"))
        #expect(!FilterCopy.refugesCouldNotSaveElsewhere.contains("this screen only"),
                "This wording must claim nothing about what is on screen")
        #expect(FilterCopy.nationName(nil) == "All of the UK")
    }

    @Test(
        "The no-matches body suggests All of the UK when a nation is chosen, and differs on the iPhone features screen, which has no nation menu or chips to clear",
        arguments: [
            (NoMatchesScope.everything, Nation?.none, "filter.noMatches.body"),
            (.rights, nil, "filter.noMatches.body"),
            (.everything, .scotland, "filter.noMatches.body.nation"),
            (.rights, .wales, "filter.noMatches.body.nation"),
            (.features, nil, "filter.noMatches.features.body"),
        ]
    )
    func noMatchesBody(scope: NoMatchesScope, nation: Nation?, key: String) {
        #expect(FilterCopy.noMatchesBody(scope, nation: nation) == Strings.localized(String.LocalizationValue(key)))
    }

    @Test("With a nation chosen, the no-matches body names All of the UK exactly as the nation menu does")
    func noMatchesNamesAllOfTheUK() {
        #expect(FilterCopy.noMatchesBody(.everything, nation: .scotland).contains(FilterCopy.allOfTheUK))
    }

    @Test("Every filter key resolves", arguments: [
        "filter.nation.title", "filter.nation.all", "filter.nation.offer", "filter.nation.couldNotRead",
        "filter.nation.couldNotSave", "refuges.nation.couldNotRead", "refuges.nation.notSaved",
        "refuges.nation.couldNotSaveElsewhere",
        "filter.topics.label", "topic.domesticAbuse", "topic.sexualViolence", "topic.stalkingAndHarassment",
        "topic.onlineAbuse", "topic.forcedMarriageAndFGM", "topic.housingAndMoney", "topic.work",
        "topic.reportingAndVictimsRights", "topic.domesticAbuse.searchTerms", "topic.sexualViolence.searchTerms",
        "topic.stalkingAndHarassment.searchTerms", "topic.onlineAbuse.searchTerms", "topic.forcedMarriageAndFGM.searchTerms",
        "topic.housingAndMoney.searchTerms", "topic.work.searchTerms", "topic.reportingAndVictimsRights.searchTerms",
        "filter.search.prompt", "filter.summary", "filter.summary.separator",
        "filter.summary.search", "filter.clear", "filter.clear.hint", "filter.clearFilters",
        "filter.noMatches.title", "filter.noMatches.rights", "filter.noMatches.body", "filter.noMatches.body.nation", "filter.noMatches.features.body", "rights.elsewhere",
        "filter.resultCount %lld",
    ])
    func keysResolve(key: String) {
        #expect(Strings.localized(String.LocalizationValue(key)) != key, "Missing catalogue entry: \(key)")
    }
}
