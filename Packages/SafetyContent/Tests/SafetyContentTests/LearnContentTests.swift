import Foundation
import SafetyDomain
import Testing

@testable import SafetyContent

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

@Suite("Your rights")
struct RightsContentTests {

    /// That every point names a nation and every topic cites a source is checked by
    /// `validate()`, which `loadUK()` runs; this checks what the sources are.
    @Test("Every topic cites only official sources")
    func officialSources() throws {
        let p = try ContentLoader.loadUK()
        #expect(!p.rights.isEmpty)
        for topic in p.rights {
            // No upper limit: every point must trace to a page listed on its own topic, and
            // a cap would delete fact-checked content rather than add a source.
            for source in topic.sources {
                let host = try #require(URL(string: source.url)?.host())
                #expect(source.url.hasPrefix("https://"))
                #expect(officialHosts.contains { host == $0 || host.hasSuffix("." + $0) }, "Not an official source: \(source.url)")
            }
        }
    }

    @Test("Domestic abuse is covered in all four nations, each by its own law")
    func domesticAbuseEverywhere() throws {
        let topic = try #require(try ContentLoader.loadUK().rights.first { $0.id == "what-counts-as-domestic-abuse" })
        let covered = Set(topic.points.flatMap(\.nations))
        #expect(covered == Set(Nation.allCases))
    }
}

@Suite("iPhone safety features")
struct FeatureContentTests {

    @Test("Every feature links to Apple's own page")
    func applePage() throws {
        for guide in try ContentLoader.loadUK().guides {
            #expect(guide.url.hasPrefix("https://support.apple.com/"), "\(guide.id) is not Apple's page")
        }
    }

    @Test("Siri calling 999 is not taught: Apple documents it only for Apple Watch")
    func noSiri() throws {
        #expect(try ContentLoader.loadUK().guides.allSatisfy { $0.id != "siri-emergency" })
    }

    @Test("Emergency SOS does not promise that contacts are always texted")
    func sosContacts() throws {
        let sos = try #require(try ContentLoader.loadUK().guides.first { $0.id == "emergency-sos" })
        let text = ([sos.summary, sos.howToUse, sos.caution].compactMap { $0 }).joined(separator: " ")
        #expect(text.contains("Messages"))
    }

    @Test("Disabling an unknown tracker warns that its owner may notice")
    func trackerOwner() throws {
        let tracker = try #require(try ContentLoader.loadUK().guides.first { $0.id == "unwanted-tracker-alerts" })
        #expect(try #require(tracker.caution).lowercased().contains("owner"))
    }
}

@Suite("Women's refuges")
struct RefugeContentTests {

    @Test("Every nation has at least one route with a phone number")
    func everyNation() throws {
        let p = try ContentLoader.loadUK()
        for nation in Nation.allCases {
            #expect(p.refuges(for: nation).contains { $0.phone != nil }, "No phone route for \(nation)")
        }
    }

    @Test("No refuge entry, and not the refuge note, carries an address")
    func noAddresses() throws {
        let p = try ContentLoader.loadUK()
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
        let note = try ContentLoader.loadUK().refugeNote
        #expect(note.text.lowercased().contains("address"))
        #expect(note.source.url.hasPrefix("https://"))
    }

    @Test("Pinned facts from the fact-check")
    func pinned() throws {
        let p = try ContentLoader.loadUK()
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
        let p = try ContentLoader.loadUK()
        #expect(!p.refuges(for: .england).contains { $0.coverage == .scotland })
        #expect(!p.refuges(for: .scotland).contains { $0.coverage == .england })
    }

    @Test("Every refuge id carries the refuge- prefix, so it never repeats a service id")
    func refugeIDPrefix() throws {
        // validate() rejects duplicate ids across collections, so a refuge route reusing
        // a helpline's service id would make the whole pack fail to load and blank every
        // tab. The prefix keeps the two apart by construction.
        for entry in try ContentLoader.loadUK().refuges {
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

    private static func refuge(id: String, coverage: String) -> String {
        #"{"id":"\#(id)","name":"R","kind":"helpline","coverage":\#(coverage),"summary":"S","phone":"0808 2000 247","url":"https://example.org/","availability":"allHours","source":"https://example.org/","topics":[]}"#
    }

    private static func supportService(id: String, topics: String) -> String {
        #"{"id":"\#(id)","name":"S","kind":"helpline","coverage":"unitedKingdom","summary":"S","url":"https://example.org/","availability":"allHours","source":"https://example.org/","topics":\#(topics)}"#
    }

    private static func packJSON(
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

    /// One refuge route, so the pack also lacks routes for three nations.
    private static func singleRefuge(coverage: String = #""england""#) -> [String] {
        [refuge(id: "r", coverage: coverage)]
    }

    private static func allNations() -> [String] {
        validRefuges.map { refuge(id: $0.id, coverage: #""\#($0.coverage)""#) }
    }

    private static func validate(_ json: String) throws {
        try JSONDecoder().decode(ContentPack.self, from: Data(json.utf8)).validate()
    }

    /// Each pack has one defect, and the failure must name it. The single-refuge packs
    /// also lack routes for three nations: points and coverage are checked first, so the
    /// failure still names the defect under test rather than a nation that merely looks
    /// empty because of it.
    static let defects: [(json: String, reason: String)] = [
        (packJSON(rightsPoint: #"{"text":"A fact.","nations":[]}"#, refuges: singleRefuge()), "a point in t names no nation"),
        (packJSON(refuges: singleRefuge(coverage: "null")), "refuge route r names no nation"),
        (packJSON(refuges: singleRefuge()), "no refuge route for wales"),
        (packJSON(services: [supportService(id: "s", topics: "[]")], refuges: allNations()), "service s has no topics"),
        (packJSON(reporting: [supportService(id: "p", topics: "[]")], refuges: allNations()), "reporting route p has no topics"),
        (packJSON(reporting: [supportService(id: "p", topics: #"["general","reportingAndVictimsRights"]"#)], refuges: allNations()),
         "reporting route p is tagged general"),
        (packJSON(rightsTopics: "[]", refuges: allNations()), "rights topic t has no topics"),
        (packJSON(rightsTopics: #"["general"]"#, refuges: allNations()), "rights topic t is tagged general"),
        (packJSON(services: [supportService(id: "s", topics: #"["domesticAbuse","domesticAbuse"]"#)], refuges: allNations()),
         "service s has a duplicate topic"),
        (packJSON(reporting: [supportService(id: "p", topics: #"["reportingAndVictimsRights","reportingAndVictimsRights"]"#)], refuges: allNations()),
         "reporting route p has a duplicate topic"),
        (packJSON(rightsTopics: #"["domesticAbuse","domesticAbuse"]"#, refuges: allNations()), "rights topic t has a duplicate topic"),
        (packJSON(refuges: allNations().map { $0.replacingOccurrences(of: #""topics":[]"#, with: #""topics":["domesticAbuse"]"#) }),
         "refuge route r-england has topics; refuges are listed by nation only"),
    ]

    @Test("A content defect is rejected at load, and the failure names it", arguments: defects)
    func rejected(json: String, reason: String) {
        #expect(throws: ContentLoader.Failure.malformed(reason)) { try Self.validate(json) }
    }

    @Test("A pack with a route for every nation and no defect passes")
    func valid() throws {
        try Self.validate(Self.packJSON(refuges: Self.allNations()))
    }

    @Test("An unknown topic fails to decode, so a typo never becomes a topic nobody can choose")
    func unknownTopic() {
        #expect(throws: DecodingError.self) {
            try Self.validate(Self.packJSON(rightsTopics: #"["pets"]"#, refuges: Self.allNations()))
        }
    }

    @Test("General on a service is valid")
    func generalOnAService() throws {
        try Self.validate(Self.packJSON(services: [Self.supportService(id: "s", topics: #"["general"]"#)], refuges: Self.allNations()))
    }
}
