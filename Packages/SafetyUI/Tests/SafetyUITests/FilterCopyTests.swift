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
        #expect(TopicCopy.names[.general] == nil)
        #expect(TopicCopy.names.count == 8)
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

    @Test("The detected-nation offer names the nation and where it came from")
    func offer() {
        #expect(FilterCopy.offer(.scotland) == "Use Scotland — detected from your location")
    }

    @Test("Store failures say what is shown instead")
    func problems() {
        #expect(FilterCopy.problem(.couldNotRead).contains("all of the UK"))
        #expect(FilterCopy.problem(.couldNotSave).contains("all of the UK"))
        #expect(FilterCopy.refugesProblem(.couldNotSave).contains("this screen only"))
        #expect(FilterCopy.nationName(nil) == "All of the UK")
    }

    @Test("The no-matches body differs on the iPhone features screen, which has no nation menu or chips to clear", arguments: [
        (NoMatchesScope.everything, "filter.noMatches.body"),
        (NoMatchesScope.rights, "filter.noMatches.body"),
        (NoMatchesScope.features, "filter.noMatches.features.body"),
    ])
    func noMatchesBody(scope: NoMatchesScope, key: String) {
        #expect(FilterCopy.noMatchesBody(scope) == Strings.localized(String.LocalizationValue(key)))
    }

    @Test("Every filter key resolves", arguments: [
        "filter.nation.title", "filter.nation.all", "filter.nation.offer", "filter.nation.couldNotRead",
        "filter.nation.couldNotSave", "refuges.nation.couldNotRead", "refuges.nation.notSaved",
        "filter.topics.label", "topic.domesticAbuse", "topic.sexualViolence", "topic.stalkingAndHarassment",
        "topic.onlineAbuse", "topic.forcedMarriageAndFGM", "topic.housingAndMoney", "topic.work",
        "topic.reportingAndVictimsRights", "filter.search.prompt", "filter.summary", "filter.summary.separator",
        "filter.summary.search", "filter.clear", "filter.clear.hint", "filter.clearFilters",
        "filter.noMatches.title", "filter.noMatches.rights", "filter.noMatches.body", "filter.noMatches.features.body", "rights.elsewhere",
        "filter.resultCount %lld",
    ])
    func keysResolve(key: String) {
        #expect(Strings.localized(String.LocalizationValue(key)) != key, "Missing catalogue entry: \(key)")
    }
}
