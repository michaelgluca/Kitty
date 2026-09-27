import Foundation
import SafetyDomain
import Testing

@testable import SafetyContent

private func pack() throws -> ContentPack { try ContentLoader.loadUK() }

/// Topic tags decide what a person sees when they choose a topic, so a wrong or missing
/// tag can hide the help they need. They are content claims, reviewed like any fact.
@Suite("Topic tags")
struct TopicTagTests {

    /// The reviewed tag table, with the evidence for each line.
    ///
    /// Rules the table follows:
    /// - A tag is given when the item's own words in the pack name the situation, or name
    ///   a class that plainly contains it ("anyone affected by crime" contains every topic
    ///   the rights content calls a crime).
    /// - When in doubt, tag. Chips combine with OR, so an extra tag only adds a row; a
    ///   missing tag hides one.
    /// - `general` is only for help open to anyone in distress, whatever is happening.
    /// - Every reporting route carries `reportingAndVictimsRights`.
    ///
    /// Changing a tag means changing its line, and its evidence, in the same commit.
    static let expected: [String: Set<Topic>] = [
        // MARK: Services

        // "for women experiencing domestic abuse". Housing: the same helpline's refuge
        // entry says advisers "help you find a refuge vacancy" (refuges-verification).
        "national-domestic-abuse-helpline": [.domesticAbuse, .housingAndMoney],
        // "domestic abuse or sexual violence". Housing: its refuge entry, "safe emergency
        // accommodation".
        "live-fear-free": [.domesticAbuse, .sexualViolence, .housingAndMoney],
        // "domestic abuse or forced marriage". Housing: its refuge entry, "your local
        // Women's Aid group, Scotland's only refuge providers".
        "scotland-domestic-abuse-forced-marriage-helpline": [.domesticAbuse, .forcedMarriageAndFGM, .housingAndMoney],
        // "domestic or sexual abuse". Housing: its refuge entry, "a referral to refuge or
        // emergency accommodation".
        "dsa-helpline-northern-ireland": [.domesticAbuse, .sexualViolence, .housingAndMoney],
        // "rape, sexual assault or any sexual violence".
        "rape-sexual-abuse-support-line": [.sexualViolence],
        // "affected by sexual violence".
        "rape-crisis-scotland": [.sexualViolence],
        // A sexual assault referral centre.
        "the-rowan": [.sexualViolence],
        // "anyone affected by crime", "you do not need to have told the police": every
        // topic the rights content calls a crime, and victims' rights.
        "victim-support": [.domesticAbuse, .sexualViolence, .stalkingAndHarassment, .onlineAbuse, .forcedMarriageAndFGM, .reportingAndVictimsRights],
        // "anyone in Scotland affected by crime", "before deciding whether to tell the police".
        "victim-support-scotland": [.domesticAbuse, .sexualViolence, .stalkingAndHarassment, .onlineAbuse, .forcedMarriageAndFGM, .reportingAndVictimsRights],
        // "about anything that is troubling you": the one line open to anyone in distress.
        "samaritans": [.general],
        // "men experiencing domestic abuse".
        "mens-advice-line": [.domesticAbuse],
        // "domestic abuse, sexual violence, hate crime": hate crime is often harassment.
        "galop": [.domesticAbuse, .sexualViolence, .stalkingAndHarassment],
        // "A directory of local domestic abuse services". Housing: the same directory lists
        // refuge services (refuge entry "Women's Aid Directory").
        "womens-aid": [.domesticAbuse, .housingAndMoney],

        // MARK: Reporting routes

        // "Every way to report a crime". The rights topics send people to the police for
        // each of these.
        "report-a-crime": [.domesticAbuse, .sexualViolence, .stalkingAndHarassment, .onlineAbuse, .forcedMarriageAndFGM, .reportingAndVictimsRights],
        // "For police matters when nobody is in danger". Rights "what you can do" names 101
        // for domestic abuse, stalking and harassment in public.
        "police-101": [.domesticAbuse, .sexualViolence, .stalkingAndHarassment, .onlineAbuse, .forcedMarriageAndFGM, .reportingAndVictimsRights],
        // An anonymous tip line that "do[es] not take your name": not a victim's own route
        // under a crime topic.
        "crimestoppers": [.reportingAndVictimsRights],
        // "something on a train, the Tube or a tram". Harassment in public names public
        // transport. Sexual violence is a reviewed judgement: the summary does not name it.
        "british-transport-police": [.sexualViolence, .stalkingAndHarassment, .reportingAndVictimsRights],
        // "a public place where you feel unsafe… somewhere you were followed". A report to
        // the police, though not of a crime.
        "streetsafe": [.stalkingAndHarassment, .reportingAndVictimsRights],

        // MARK: Rights topics

        // "controlling your money": economic abuse.
        "what-counts-as-domestic-abuse": [.domesticAbuse, .housingAndMoney],
        // "whether your partner or an ex-partner has a history of abuse".
        "ask-about-a-partner": [.domesticAbuse],
        // "order an abuser to stop harming or threatening you".
        "protection-orders": [.domesticAbuse],
        // "If abuse means you can't stay at home, you can get help with housing".
        "housing-help": [.domesticAbuse, .housingAndMoney],
        // "You can report rape or sexual assault at any time"; anonymity "if you report".
        "sexual-violence": [.sexualViolence, .reportingAndVictimsRights],
        // "watching you online"; "monitoring your phone, email or internet use".
        "stalking-and-harassment": [.stalkingAndHarassment, .onlineAbuse],
        // Intimate images, deepfakes and cyberflashing are offences in the Sexual Offences
        // Act 2003, ss.66A–66H (rights-verification).
        "online-abuse": [.onlineAbuse, .sexualViolence],
        // "must take steps to prevent sexual harassment".
        "rights-at-work": [.work, .stalkingAndHarassment],
        // "If a crime happens to you, you have rights".
        "victims-rights": [.reportingAndVictimsRights],
        // Title and summary.
        "forced-marriage-and-fgm": [.forcedMarriageAndFGM],
        // "threatened, harassed or intimidated in public". Not tagged sexual violence: the
        // offence is harassment, though the government's examples include threats.
        "harassment-in-public": [.stalkingAndHarassment],
    ]

    @Test("Every service, reporting route and rights topic carries exactly its reviewed tags")
    func pinned() throws {
        let p = try pack()
        var actual: [String: Set<Topic>] = [:]
        for item in p.services + p.reporting(for: .unitedKingdom) { actual[item.id] = Set(item.topics) }
        for topic in p.rights { actual[topic.id] = Set(topic.topics) }
        #expect(actual == Self.expected)
    }

    @Test("Nothing is untagged")
    func everythingTagged() throws {
        let p = try pack()
        for item in p.services + p.reporting(for: .unitedKingdom) { #expect(!item.topics.isEmpty, "\(item.id) has no topics") }
        for topic in p.rights { #expect(!topic.topics.isEmpty, "\(topic.id) has no topics") }
    }

    @Test("General is never on a right or a reporting route")
    func generalOnlyOnServices() throws {
        let p = try pack()
        #expect(p.rights.allSatisfy { !$0.topics.contains(.general) })
        #expect(p.reporting(for: .unitedKingdom).allSatisfy { !$0.topics.contains(.general) })
    }

    @Test("Every reporting route is found under Reporting & victims' rights")
    func reportingRoutesAreReporting() throws {
        for route in try pack().reporting(for: .unitedKingdom) {
            #expect(route.topics.contains(.reportingAndVictimsRights), "\(route.id)")
        }
    }

    @Test("Refuge routes carry no topics: Refuges lists them by nation alone")
    func refugesUntagged() throws {
        #expect(try pack().refuges.allSatisfy { $0.topics.isEmpty })
    }

    @Test("Every chip finds something on Get help or Learn")
    func everyChipHasHelp() throws {
        let p = try pack()
        let tagged = p.services + p.reporting(for: .unitedKingdom)
        for topic in Topic.selectable {
            let found = tagged.contains { $0.topics.contains(topic) } || p.rights.contains { $0.topics.contains(topic) }
            #expect(found, "Nothing is tagged \(topic)")
        }
    }

    @Test("Eight chips, in order, and general is not one")
    func chips() {
        #expect(Topic.selectable == [
            .domesticAbuse, .sexualViolence, .stalkingAndHarassment, .onlineAbuse,
            .forcedMarriageAndFGM, .housingAndMoney, .work, .reportingAndVictimsRights,
        ])
    }
}
