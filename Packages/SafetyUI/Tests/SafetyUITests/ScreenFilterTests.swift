import Foundation
import SafetyContent
import SafetyDomain
import SafetyTesting
import Testing

@testable import SafetyUI

/// The search words the screens use, from the String Catalog.
private let terms = TopicCopy.searchTerms

@MainActor
@Suite("Screen filter and what each screen shows")
struct ScreenFilterTests {

    private func pack() throws -> ContentPack { try ContentLoader.loadUK() }

    @Test("The 999 routes are never filtered, whatever the nation, topics, search or region")
    func emergencyRoutesNeverFiltered() throws {
        let p = try pack()
        let nations: [Nation?] = [nil] + Nation.allCases.map(Optional.some)
        let topicSets: [Set<Topic>] = [[]] + Topic.selectable.map { [$0] } + [Set(Topic.selectable)]
        for nation in nations {
            for topics in topicSets {
                for query in ["", "stalking", "zzqx nothing matches this"] {
                    for region in [RegionStance.unitedKingdom, .elsewhere(countryCode: "US")] {
                        let criteria = FilterCriteria(nation: nation, topics: topics, query: query)
                        let content = HelpContent(pack: p, region: region, criteria: criteria, topicTerms: terms)
                        #expect(content.emergencyRoutes == p.emergencyRoutes)
                    }
                }
            }
        }
    }

    @Test("Nothing matching is reported even though the 999 routes are still on screen")
    func noMatchesDespite999() throws {
        let p = try pack()
        let content = HelpContent(pack: p, region: .unitedKingdom, criteria: FilterCriteria(query: "zzqx"), topicTerms: terms)
        #expect(content.hasNoMatches)
        #expect(content.resultCount == 0)
        #expect(!content.emergencyRoutes.isEmpty)
    }

    @Test("Clearing topics and search never leaves Get help or Learn empty, for any nation")
    func clearedIsNeverEmpty() throws {
        let p = try pack()
        for nation in [Nation?.none] + Nation.allCases.map(Optional.some) {
            let criteria = FilterCriteria(nation: nation)
            #expect(!HelpContent(pack: p, region: .unitedKingdom, criteria: criteria, topicTerms: terms).hasNoMatches,
                    "\(String(describing: nation))")
            #expect(!LearnContent(pack: p, criteria: criteria, topicTerms: terms).rights.isEmpty,
                    "\(String(describing: nation))")
        }
    }

    @Test("Scotland shows Scotland's helpline and not England's; help with no stated coverage stays")
    func scotland() throws {
        let content = HelpContent(pack: try pack(), region: .unitedKingdom, criteria: FilterCriteria(nation: .scotland), topicTerms: terms)
        let ids = content.services.map(\.id)
        #expect(ids.contains("scotland-domestic-abuse-forced-marriage-helpline"))
        #expect(!ids.contains("national-domestic-abuse-helpline"))
        #expect(ids.contains("galop"))
    }

    @Test("Outside the UK, crime reporting stays withheld whatever the filter (Guideline 1.7)")
    func reportingGateKept() throws {
        let content = HelpContent(
            pack: try pack(), region: .elsewhere(countryCode: "US"),
            criteria: FilterCriteria(topics: [.reportingAndVictimsRights]), topicTerms: terms
        )
        #expect(content.reporting.isEmpty)
    }

    @Test("Learn's iPhone features ignore the nation and topics, and answer only to search")
    func guidesSearchOnly() throws {
        let p = try pack()
        #expect(LearnContent(pack: p, criteria: FilterCriteria(nation: .northernIreland, topics: [.work]), topicTerms: terms).guides == p.guides)
        let searched = LearnContent(pack: p, criteria: FilterCriteria(query: "crash detection"), topicTerms: terms)
        #expect(searched.guides.map(\.id) == ["crash-detection"])
        #expect(searched.rights.isEmpty, "No right mentions crash detection")
        #expect(!searched.hasNoMatches, "Features still match, so the screen is not empty")
    }

    @Test("Toggling a topic twice deselects it")
    func toggle() {
        let filter = ScreenFilter()
        filter.toggle(.work)
        #expect(filter.topics == [.work])
        filter.toggle(.work)
        #expect(filter.topics.isEmpty)
    }

    @Test("Clear resets topics and search, and keeps the nation")
    func clearKeepsNation() {
        let preference = NationPreference(store: InMemoryNationStore(saved: "scotland"))
        preference.load()
        let filter = ScreenFilter()
        filter.toggle(.work)
        filter.query = "refuge"
        #expect(filter.canClear)
        filter.clear()
        #expect(filter.topics.isEmpty)
        #expect(filter.query.isEmpty)
        #expect(preference.nation == .scotland)
        #expect(filter.criteria(nation: preference.nation) == FilterCriteria(nation: .scotland))
    }

    @Test("A search of only spaces or punctuation leaves nothing to clear")
    func nothingToClear() {
        let filter = ScreenFilter()
        filter.query = " & "
        #expect(!filter.canClear)
    }
}
