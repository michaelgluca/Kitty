import Foundation
import SafetyDomain
import Testing

@testable import SafetyContent

private func pack() throws -> ContentPack { try ContentLoader.loadUK() }

/// A UK postcode, such as "SW1A 2AA". A refuge address must never appear in the pack.
///
/// A computed property rather than a global `let`: `Regex` is not `Sendable`, so a
/// global constant does not compile under Swift 6.
private var postcode: Regex<Substring> { /\b[A-Z]{1,2}[0-9][0-9A-Z]? ?[0-9][A-Z]{2}\b/ }

private let officialHosts = [
    "gov.uk", "legislation.gov.uk", "gov.scot", "mygov.scot", "gov.wales", "nidirect.gov.uk",
    "police.uk", "cps.gov.uk", "copfs.gov.uk", "judiciary.uk", "acas.org.uk",
    "equalityhumanrights.com", "lra.org.uk", "justice-ni.gov.uk",
    // The Public Prosecution Service for Northern Ireland.
    "ppsni.gov.uk",
]

@Suite("Coverage and nations")
struct CoverageTests {

    @Test("Coverage includes exactly the nations it names")
    func includes() {
        #expect(Coverage.unitedKingdom.includes(.northernIreland))
        #expect(Coverage.greatBritain.includes(.scotland))
        #expect(!Coverage.greatBritain.includes(.northernIreland))
        #expect(Coverage.englandAndWales.includes(.wales))
        #expect(!Coverage.englandAndWales.includes(.scotland))
        #expect(Coverage.london.includes(.england))
        #expect(!Coverage.england.includes(.wales))
    }
}

@Suite("Your rights")
struct RightsContentTests {

    @Test("Every point says which nations it applies in, and every topic cites an official source")
    func structure() throws {
        let p = try pack()
        #expect(!p.rights.isEmpty)
        for topic in p.rights {
            #expect(!topic.points.isEmpty, "\(topic.id) has no points")
            #expect(topic.points.allSatisfy { !$0.nations.isEmpty }, "\(topic.id) has a point with no nation")
            // No upper limit: every point must trace to a page listed on its own topic, and
            // a cap would delete fact-checked content rather than add a source.
            #expect(!topic.sources.isEmpty, "\(topic.id) has no source")
            for source in topic.sources {
                let host = try #require(URL(string: source.url)?.host())
                #expect(source.url.hasPrefix("https://"))
                #expect(officialHosts.contains { host == $0 || host.hasSuffix("." + $0) }, "Not an official source: \(source.url)")
            }
        }
    }

    @Test("Domestic abuse is covered in all four nations, each by its own law")
    func domesticAbuseEverywhere() throws {
        let topic = try #require(try pack().rights.first { $0.id == "what-counts-as-domestic-abuse" })
        let covered = Set(topic.points.flatMap(\.nations))
        #expect(covered == Set(Nation.allCases))
    }
}

@Suite("iPhone safety features")
struct FeatureContentTests {

    @Test("Every feature has setup steps and Apple's own page")
    func structure() throws {
        for guide in try pack().guides {
            #expect(!guide.steps.isEmpty, "\(guide.id) has no steps")
            #expect(guide.url.hasPrefix("https://support.apple.com/"), "\(guide.id) is not Apple's page")
        }
    }

    @Test("Siri calling 999 is not taught: Apple documents it only for Apple Watch")
    func noSiri() throws {
        #expect(try pack().guides.allSatisfy { $0.id != "siri-emergency" })
    }

    @Test("Emergency SOS does not promise that contacts are always texted")
    func sosContacts() throws {
        let sos = try #require(try pack().guides.first { $0.id == "emergency-sos" })
        let text = ([sos.summary, sos.howToUse, sos.caution].compactMap { $0 }).joined(separator: " ")
        #expect(text.contains("Messages"))
    }

    @Test("Disabling an unknown tracker warns that its owner may notice")
    func trackerOwner() throws {
        let tracker = try #require(try pack().guides.first { $0.id == "unwanted-tracker-alerts" })
        #expect(try #require(tracker.caution).lowercased().contains("owner"))
    }
}

@Suite("Women's refuges")
struct RefugeContentTests {

    @Test("Every nation has at least one route with a phone number")
    func everyNation() throws {
        let p = try pack()
        for nation in Nation.allCases {
            #expect(p.refuges(for: nation).contains { $0.phone != nil }, "No phone route for \(nation)")
        }
    }

    @Test("No refuge entry, and not the refuge note, carries an address")
    func noAddresses() throws {
        let p = try pack()
        for entry in p.refuges {
            let text = [entry.name, entry.summary, entry.audience, entry.billingNote, entry.textNote]
                .compactMap { $0 }
                .joined(separator: " ")
            #expect(text.firstMatch(of: postcode) == nil, "\(entry.id) contains what looks like a postcode")
        }
        #expect(p.refugeNote.text.firstMatch(of: postcode) == nil, "The refuge note contains what looks like a postcode")
    }

    @Test("The note explains why there are no addresses")
    func note() throws {
        let note = try pack().refugeNote
        #expect(note.text.lowercased().contains("address"))
        #expect(note.source.url.hasPrefix("https://"))
    }

    @Test("Pinned facts from the fact-check")
    func pinned() throws {
        let p = try pack()
        let all = p.refuges
        #expect(all.first { $0.name == "National Domestic Abuse Helpline" }?.phone == "0808 2000 247")
        #expect(all.contains { $0.name == "Scotland's Domestic Abuse and Forced Marriage Helpline" })
        // GOV.UK lists Live Fear Free as 0808 80 10 100. The operator's number is 0808 80 10 800.
        #expect(!all.contains { $0.phone == "0808 80 10 100" })
        #expect(all.contains { $0.phone == "0808 80 10 800" && $0.coverage == .wales })
        // The Housing Executive's daytime number is published on the cited page.
        #expect(all.contains { $0.phone == "03448 920 900" && $0.coverage == .northernIreland })
        // Priority need depends on eligibility; women with no recourse to public funds
        // are usually not eligible, and must be told where else to turn.
        #expect(all.contains { ($0.summary + " " + ($0.audience ?? "")).lowercased().contains("no recourse to public funds") })
    }

    @Test("England's list never includes a Scotland-only service, and vice versa")
    func perNation() throws {
        let p = try pack()
        #expect(!p.refuges(for: .england).contains { $0.coverage == .scotland })
        #expect(!p.refuges(for: .scotland).contains { $0.coverage == .england })
    }

    @Test("No refuge id repeats a service id, so the pack's id check can never blank every tab")
    func refugeIDsAreDistinct() throws {
        // validate() rejects duplicate ids across collections, and loadUK() calls it.
        // A refuge route reusing a helpline's service id would make the whole pack fail
        // to load. Refuge ids therefore carry a `refuge-` prefix.
        let p = try pack()
        let serviceIDs = Set(p.services.map(\.id))
        for entry in p.refuges {
            #expect(!serviceIDs.contains(entry.id), "\(entry.id) is also a service id")
            #expect(entry.id.hasPrefix("refuge-"), "\(entry.id) lacks the refuge- prefix")
        }
    }
}

@Suite("Content validation")
struct ContentValidationTests {

    private static let validRefuges = [
        (id: "r-england", coverage: "england"), (id: "r-wales", coverage: "wales"),
        (id: "r-scotland", coverage: "scotland"), (id: "r-ni", coverage: "northernIreland"),
    ]

    private func refuge(id: String, coverage: String) -> String {
        #"{"id":"\#(id)","name":"R","kind":"helpline","coverage":\#(coverage),"summary":"S","phone":"0808 2000 247","url":"https://example.org/","availability":"allHours","source":"https://example.org/","topics":[]}"#
    }

    private func supportService(id: String, topics: String) -> String {
        #"{"id":"\#(id)","name":"S","kind":"helpline","coverage":"unitedKingdom","summary":"S","url":"https://example.org/","availability":"allHours","source":"https://example.org/","topics":\#(topics)}"#
    }

    private func packJSON(
        rightsPoint: String = #"{"text":"A fact.","nations":["england"]}"#,
        rightsTopics: String = #"["domesticAbuse"]"#,
        services: [String] = [],
        reporting: [String] = [],
        refuges: [String]
    ) -> String {
        """
        {"version":6,"reviewedOn":"2026-09-27","emergencyNumber":"999","emergencyRoutes":[],"services":[\(services.joined(separator: ","))],"reporting":[\(reporting.joined(separator: ","))],"guides":[],
         "rights":[{"id":"t","title":"T","summary":"S","points":[\(rightsPoint)],"whatYouCanDo":"W","sources":[{"title":"GOV.UK","url":"https://www.gov.uk/"}],"topics":\(rightsTopics)}],
         "refuges":[\(refuges.joined(separator: ","))],
         "refugeNote":{"text":"No addresses.","source":{"title":"X","url":"https://example.org/"}}}
        """
    }

    private func englandOnly(coverage: String = #""england""#) -> [String] {
        [refuge(id: "r", coverage: coverage)]
    }

    private func allNations() -> [String] {
        Self.validRefuges.map { refuge(id: $0.id, coverage: #""\#($0.coverage)""#) }
    }

    private func validate(_ json: String) throws {
        try JSONDecoder().decode(ContentPack.self, from: Data(json.utf8)).validate()
    }

    @Test("A point that names no nation is rejected at load")
    func pointWithoutNation() {
        #expect(throws: (any Error).self) {
            try validate(packJSON(rightsPoint: #"{"text":"A fact.","nations":[]}"#, refuges: englandOnly()))
        }
    }

    @Test("A refuge route with no nation is rejected at load")
    func refugeWithoutNation() {
        #expect(throws: (any Error).self) { try validate(packJSON(refuges: englandOnly(coverage: "null"))) }
    }

    @Test("The defect named is the point with no nation, not the missing nations")
    func pointCheckedFirst() {
        // Both fixtures above also lack routes for three nations. validate() checks
        // points and coverage first, so the failure names the defect being tested.
        #expect(throws: ContentLoader.Failure.malformed("a point in t names no nation")) {
            try validate(packJSON(rightsPoint: #"{"text":"A fact.","nations":[]}"#, refuges: englandOnly()))
        }
        #expect(throws: ContentLoader.Failure.malformed("refuge route r names no nation")) {
            try validate(packJSON(refuges: englandOnly(coverage: "null")))
        }
    }

    @Test("A nation left without a refuge route is rejected at load")
    func nationWithoutRoute() {
        #expect(throws: ContentLoader.Failure.malformed("no refuge route for wales")) {
            try validate(packJSON(refuges: englandOnly()))
        }
    }

    @Test("A pack with a route for every nation and no defect passes")
    func valid() throws {
        try validate(packJSON(refuges: allNations()))
    }
}
