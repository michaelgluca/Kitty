import Foundation
import Testing

@testable import SafetyContent

// Fixtures are decoded from JSON, as the pack is, so they pass through the same decoder
// and cannot be something the pack could never hold.

private func service(
    _ id: String,
    name: String = "Name",
    summary: String = "Summary",
    audience: String? = nil,
    coverage: Coverage? = .unitedKingdom,
    topics: [Topic] = [.domesticAbuse]
) throws -> SupportService {
    var object: [String: Any] = [
        "id": id, "name": name, "kind": "helpline", "summary": summary,
        "url": "https://example.org/", "availability": "allHours", "source": "https://example.org/",
        "topics": topics.map(\.rawValue),
    ]
    if let audience { object["audience"] = audience }
    if let coverage { object["coverage"] = coverage.rawValue }
    return try JSONDecoder().decode(SupportService.self, from: JSONSerialization.data(withJSONObject: object))
}

private func rightsTopic(
    _ id: String,
    title: String = "Title",
    summary: String = "Summary",
    points: [[Nation]],
    topics: [Topic] = [.domesticAbuse]
) throws -> RightsTopic {
    let pointObjects: [[String: Any]] = points.enumerated().map { index, nations in
        ["text": "Point \(index)", "nations": nations.map(\.rawValue)]
    }
    let object: [String: Any] = [
        "id": id, "title": title, "summary": summary, "points": pointObjects,
        "whatYouCanDo": "W", "sources": [["title": "GOV.UK", "url": "https://www.gov.uk/"]],
        "topics": topics.map(\.rawValue),
    ]
    return try JSONDecoder().decode(RightsTopic.self, from: JSONSerialization.data(withJSONObject: object))
}

private func guide(_ id: String, title: String, summary: String = "Summary") throws -> SafetyGuide {
    let object: [String: Any] = [
        "id": id, "title": title, "summary": summary, "steps": ["Open Settings."], "url": "https://support.apple.com/",
    ]
    return try JSONDecoder().decode(SafetyGuide.self, from: JSONSerialization.data(withJSONObject: object))
}

/// The chip names as SafetyUI supplies them in English.
private let names: [Topic: String] = [
    .domesticAbuse: "Domestic abuse", .sexualViolence: "Sexual violence",
    .stalkingAndHarassment: "Stalking & harassment", .onlineAbuse: "Online abuse",
    .forcedMarriageAndFGM: "Forced marriage & FGM", .housingAndMoney: "Housing & money",
    .work: "Work", .reportingAndVictimsRights: "Reporting & victims' rights",
]

private func ids(_ items: [SupportService]) -> [String] { items.map(\.id) }

@Suite("Content filter: nation")
struct NationFilterTests {

    /// Written out, not computed from `Coverage.includes(_:)`, so the rule is pinned on
    /// its own. `london` counts as England.
    static let expected: [Coverage: Set<Nation>] = [
        .unitedKingdom: Set(Nation.allCases),
        .greatBritain: [.england, .wales, .scotland],
        .england: [.england],
        .englandAndWales: [.england, .wales],
        .wales: [.wales],
        .scotland: [.scotland],
        .northernIreland: [.northernIreland],
        .london: [.england],
    ]

    @Test("The table covers every coverage")
    func complete() {
        #expect(Set(Self.expected.keys) == Set(Coverage.allCases))
    }

    @Test("A service shows in exactly the nations its coverage reaches", arguments: Coverage.allCases)
    func coverage(_ coverage: Coverage) throws {
        let item = try service("s", coverage: coverage)
        for nation in Nation.allCases {
            let shown = !ContentFilter.services([item], matching: FilterCriteria(nation: nation), topicNames: names).isEmpty
            #expect(shown == Self.expected[coverage]?.contains(nation), "\(coverage) in \(nation)")
        }
    }

    @Test("Help with no stated coverage shows in every nation: when in doubt, show")
    func noCoverage() throws {
        let galop = try service("galop", coverage: nil)
        for nation in Nation.allCases {
            #expect(ids(ContentFilter.services([galop], matching: FilterCriteria(nation: nation), topicNames: names)) == ["galop"])
        }
    }

    @Test("With no nation chosen, help for every nation shows")
    func allOfTheUK() throws {
        let items = try Coverage.allCases.map { try service($0.rawValue, coverage: $0) }
        #expect(ContentFilter.services(items, matching: FilterCriteria(), topicNames: names).count == items.count)
    }
}

@Suite("Content filter: topics")
struct TopicFilterTests {

    @Test("Chosen topics combine with OR")
    func combineWithOr() throws {
        let items = [
            try service("a", topics: [.domesticAbuse]),
            try service("b", topics: [.sexualViolence]),
            try service("c", topics: [.stalkingAndHarassment]),
        ]
        let shown = ContentFilter.services(items, matching: FilterCriteria(topics: [.domesticAbuse, .sexualViolence]), topicNames: names)
        #expect(ids(shown) == ["a", "b"])
    }

    @Test("Help for anyone in distress shows under every topic", arguments: Topic.selectable)
    func general(_ topic: Topic) throws {
        let samaritans = try service("samaritans", topics: [.general])
        #expect(ids(ContentFilter.services([samaritans], matching: FilterCriteria(topics: [topic]), topicNames: names)) == ["samaritans"])
    }

    @Test("No topic chosen shows every topic")
    func noneChosen() throws {
        let items = [try service("a", topics: [.work]), try service("b", topics: [.onlineAbuse])]
        #expect(ContentFilter.services(items, matching: FilterCriteria(), topicNames: names).count == 2)
    }

    @Test("A rights topic shows when it carries any chosen topic")
    func rights() throws {
        let work = try rightsTopic("work", points: [Nation.allCases], topics: [.work])
        let fm = try rightsTopic("fm", points: [Nation.allCases], topics: [.forcedMarriageAndFGM])
        #expect(ContentFilter.rights([work, fm], matching: FilterCriteria(topics: [.work]), topicNames: names).map(\.id) == ["work"])
    }
}

@Suite("Content filter: search")
struct SearchFilterTests {

    private func finds(_ query: String, _ item: SupportService) -> Bool {
        !ContentFilter.services([item], matching: FilterCriteria(query: query), topicNames: names).isEmpty
    }

    @Test("Every word typed must appear, in any field, in any order")
    func everyWord() throws {
        let item = try service("s", name: "Rape Crisis Helpline", summary: "Free support, every evening.")
        #expect(finds("helpline free", item))
        #expect(finds("evening rape", item))
        #expect(!finds("rape zebra", item))
    }

    @Test("Case and accents are ignored, both ways")
    func caseAndDiacritics() throws {
        #expect(finds("CAFE", try service("s", name: "Café Line")))
        #expect(finds("café", try service("s", name: "Cafe Line")))
    }

    @Test("A curly apostrophe from iOS smart punctuation finds a straight one, and the reverse")
    func curlyApostrophe() throws {
        let straight = try service("s", name: "Women's Aid")
        let curly = try service("t", name: "Women\u{2019}s Aid")
        #expect(curly.name.unicodeScalars.contains(where: { $0.value == 0x2019 }), "Curly fixture must contain U+2019")
        #expect(finds("women's aid", straight))
        #expect(finds("women's aid", curly))
        #expect(finds("women\u{2019}s aid", curly), "Curly query finds curly fixture")
        #expect(finds("womens", straight))
        #expect(finds("womens", curly), "Folded query finds both variants")
    }

    @Test("Who a service is for is searched")
    func audience() throws {
        #expect(finds("lgbt", try service("s", audience: "LGBT+ people aged 18 and over")))
    }

    @Test("Topic names are searched, so 'stalking' finds help tagged Stalking & harassment")
    func topicNames() throws {
        let item = try service("s", name: "Supportline", summary: "For anyone affected by crime.", topics: [.stalkingAndHarassment])
        #expect(finds("stalking", item))
        #expect(ContentFilter.services([item], matching: FilterCriteria(query: "stalking"), topicNames: [:]).isEmpty,
                "Found only through the topic's name")
    }

    @Test("Spaces or punctuation alone are no search at all")
    func nothingSearchable() throws {
        let item = try service("s")
        for query in ["", "   ", " & ", "\u{201C}\u{201D}", "…"] {
            #expect(FilterCriteria(query: query).words.isEmpty, "\(query)")
            #expect(finds(query, item), "\(query)")
        }
    }

    @Test("Words are folded, and trimmed of the punctuation around them")
    func words() {
        #expect(SearchText.words(in: "  Women's   AID, \u{201C}Stalking\u{201D} ") == ["womens", "aid", "stalking"])
    }

    @Test("Folding uses a fixed locale, never the phone's, so every phone finds the same help")
    func fixedLocale() {
        #expect(SearchText.locale.identifier == "en_GB")
        #expect(SearchText.normalise("STALKING") == "stalking")
        #expect(SearchText.normalise("ＣＡＦÉ") == "cafe")
    }

    @Test("Search combines with the nation: both must match")
    func withNation() throws {
        let england = try service("e", name: "Stalking line", coverage: .england)
        #expect(ContentFilter.services([england], matching: FilterCriteria(nation: .scotland, query: "stalking"), topicNames: names).isEmpty)
        #expect(ids(ContentFilter.services([england], matching: FilterCriteria(nation: .england, query: "stalking"), topicNames: names)) == ["e"])
    }

    @Test("Search combines with topics: both must match")
    func withTopics() throws {
        let item = try service("s", name: "Stalking line", topics: [.stalkingAndHarassment])
        #expect(ContentFilter.services([item], matching: FilterCriteria(topics: [.work], query: "stalking"), topicNames: names).isEmpty)
    }

    @Test("Nothing matching gives nothing, never a guess")
    func noMatches() throws {
        #expect(ContentFilter.services([try service("s")], matching: FilterCriteria(query: "zzqx"), topicNames: names).isEmpty)
    }
}

@Suite("Content filter: rights")
struct RightsFilterTests {

    @Test("A topic's points split into those for the nation and the rest, and none are lost")
    func split() throws {
        let topic = try rightsTopic("t", points: [[.england, .wales], [.scotland], Nation.allCases])
        let match = ContentFilter.split(topic, for: .scotland)
        #expect(match.here.map(\.text) == ["Point 1", "Point 2"])
        #expect(match.elsewhere.map(\.text) == ["Point 0"])
    }

    @Test("With no nation chosen, every point is shown and none is set aside")
    func noNation() throws {
        let topic = try rightsTopic("t", points: [[.england], [.scotland]])
        let match = ContentFilter.split(topic, for: nil)
        #expect(match.here.count == 2)
        #expect(match.elsewhere.isEmpty)
    }

    @Test("A topic shows when any of its points applies in the nation")
    func anyPoint() throws {
        let topic = try rightsTopic("t", points: [[.england], [.northernIreland]])
        #expect(ContentFilter.rights([topic], matching: FilterCriteria(nation: .northernIreland), topicNames: names).map(\.id) == ["t"])
        #expect(ContentFilter.rights([topic], matching: FilterCriteria(nation: .scotland), topicNames: names).isEmpty)
    }

    @Test("Rights are searched by title, summary and topic names")
    func search() throws {
        let topic = try rightsTopic("t", title: "Your rights at work", summary: "Equal pay.", points: [Nation.allCases], topics: [.work, .stalkingAndHarassment])
        for query in ["WORK", "equal", "stalking"] {
            #expect(!ContentFilter.rights([topic], matching: FilterCriteria(query: query), topicNames: names).isEmpty, "\(query)")
        }
        #expect(ContentFilter.rights([topic], matching: FilterCriteria(query: "zzqx"), topicNames: names).isEmpty)
    }
}

@Suite("Content filter: iPhone features")
struct GuideFilterTests {

    @Test("Features ignore the nation and topics: they are the same everywhere")
    func ignoresNationAndTopics() throws {
        let guides = [try guide("check-in", title: "Check In"), try guide("emergency-sos", title: "Emergency SOS")]
        #expect(ContentFilter.guides(guides, matching: FilterCriteria(nation: .scotland, topics: [.work])) == guides)
    }

    @Test("Features answer to search")
    func search() throws {
        let guides = [try guide("check-in", title: "Check In"), try guide("emergency-sos", title: "Emergency SOS")]
        #expect(ContentFilter.guides(guides, matching: FilterCriteria(query: "check")).map(\.id) == ["check-in"])
    }
}
