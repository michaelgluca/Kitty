import Foundation
import SafetyDomain
import Testing

@testable import SafetyContent

// Content is treated as code. Every test here pins a fact that was verified against
// the issuing body's own page, and most pin an error that was either shipped by the
// 2023 build or caught during verification. Each one would cause real harm if it
// regressed.

private func pack() throws -> ContentPack { try ContentLoader.loadUK() }
private func service(_ id: String) throws -> SupportService {
    try #require(try pack().services.first { $0.id == id }, "No service \(id)")
}
private func route(_ id: String) throws -> EmergencyRoute {
    try #require(try pack().emergencyRoutes.first { $0.id == id }, "No route \(id)")
}
private func guide(_ id: String) throws -> SafetyGuide {
    try #require(try pack().guides.first { $0.id == id }, "No guide \(id)")
}

@Suite("Content pack: structure")
struct ContentStructureTests {

    @Test("Loads, and is the current version")
    func loads() throws {
        let p = try pack()
        #expect(p.version == 2)
        #expect(!p.services.isEmpty && !p.emergencyRoutes.isEmpty && !p.guides.isEmpty)
    }

    @Test("Identifiers are unique within each section")
    func uniqueIDs() throws {
        let p = try pack()
        #expect(Set(p.services.map(\.id)).count == p.services.count)
        #expect(Set(p.emergencyRoutes.map(\.id)).count == p.emergencyRoutes.count)
        #expect(Set(p.guides.map(\.id)).count == p.guides.count)
    }

    @Test("Every nation has a domestic abuse line open at any hour")
    func everyNationCovered() throws {
        // The 2023 build listed English services only and presented them as though
        // they were UK-wide, which sends someone in Glasgow or Belfast to the wrong
        // place. Each nation must have its own 24-hour route.
        let p = try pack()
        for nation in [Coverage.england, .wales, .scotland, .northernIreland] {
            let found = p.services.contains {
                $0.coverage == nation && $0.availability == .allHours && $0.phone != nil
            }
            #expect(found, "No 24-hour line covering \(nation)")
        }
    }

    @Test("Round-trips through JSON without losing anything")
    func roundTrips() throws {
        let original = try pack()
        let decoded = try JSONDecoder().decode(ContentPack.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}

@Suite("Content pack: phone numbers")
struct PhoneNumberContentTests {

    @Test("Every phone number is dialable")
    func allDialable() throws {
        for s in try pack().services {
            guard let phone = s.phone else { continue }
            #expect(PhoneNumber(phone) != nil, "\(s.id) has an undialable number: \(phone)")
        }
    }

    @Test("No service carries an emergency short code as a phone number")
    func noEmergencyShortCodes() throws {
        // A service's `phone` is rendered as a CALL button. If a "Text 999" entry ever
        // carried 999 here, tapping it would place a VOICE call for someone who
        // cannot speak — the exact failure that route exists to prevent. Emergency
        // numbers belong in emergencyRoutes, which have no dialable field at all.
        let forbidden: Set = ["999", "112", "18000", "18001", "61016"]
        for s in try pack().services {
            guard let phone = s.phone, let dialable = PhoneNumber(phone)?.dialable else { continue }
            #expect(!forbidden.contains(dialable), "\(s.id) carries emergency short code \(dialable)")
        }
    }

    @Test("Numbers are shown in readable groups, not as an unbroken string of digits")
    func readable() throws {
        // "08085002222" is hard to read under stress and easy to misdial by hand.
        for s in try pack().services {
            guard let phone = s.phone, phone.count > 7 else { continue }
            #expect(phone.contains(" "), "\(s.id) number is not grouped: \(phone)")
        }
    }

    @Test("Live Fear Free uses the Welsh Government's number, not GOV.UK's")
    func walesNumber() throws {
        // GOV.UK's domestic abuse guidance publishes 0808 80 10 100. The service's own
        // operator, GOV.WALES, gives 0808 80 10 800 on two separate pages. Copying the
        // GOV.UK digits would be an easy, plausible and wrong edit.
        let s = try service("live-fear-free")
        #expect(PhoneNumber(try #require(s.phone))?.dialable == "08088010800")
    }

    @Test("Headline numbers are exactly as verified")
    func headlineNumbers() throws {
        let expected = [
            "national-domestic-abuse-helpline": "08082000247",
            "scotland-domestic-abuse-forced-marriage-helpline": "08000271234",
            "dsa-helpline-northern-ireland": "08088021414",
            "rape-sexual-abuse-support-line": "08085002222",
            "samaritans": "116123",
        ]
        for (id, digits) in expected {
            #expect(PhoneNumber(try #require(try service(id).phone))?.dialable == digits, "\(id)")
        }
    }
}

@Suite("Content pack: facts that were wrong or have changed")
struct ContentFactTests {

    @Test("Women's Aid has no phone line, and its closed live chat is not offered")
    func womensAid() throws {
        // Women's Aid runs no telephone helpline, and its live chat closed on
        // 31 July 2025. chat.womensaid.org.uk now redirects elsewhere — which a link
        // checker that follows redirects would happily report as healthy.
        let s = try service("womens-aid")
        #expect(s.phone == nil)
        #expect(!s.url.contains("chat.womensaid"))
        #expect(s.summary.lowercased().contains("closed"))
        #expect(s.availability == .seeWebsite)
    }

    @Test("Galop's coverage is left blank, because Galop does not state it")
    func galopCoverage() throws {
        // Presenting a nation the operator has not claimed would be inventing a fact.
        #expect(try service("galop").coverage == nil)
    }

    @Test("Lines that are not 24/7 are never marked as open at any hour")
    func limitedHours() throws {
        // A man in crisis at 2am who is told the Men's Advice Line is open gets
        // nothing when he calls.
        for id in ["mens-advice-line", "rape-crisis-scotland", "victim-support-scotland"] {
            #expect(try service(id).availability != .allHours, "\(id) is not a 24-hour line")
        }
    }

    @Test("The Men's Advice Line points to a line that is open when it is not")
    func mensAdviceLinePointsElsewhere() throws {
        #expect(try service("mens-advice-line").summary.contains("Samaritans"))
    }

    @Test("The Rowan uses its working address, not the one that times out")
    func rowanURL() throws {
        // therowan.net is the address most commonly published for Northern Ireland's
        // only sexual assault referral centre, and its TLS connection times out.
        let s = try service("the-rowan")
        #expect(s.url.contains("hscni.net"))
        #expect(!s.url.contains("therowan.net"))
    }

    @Test("Billing claims appear only where the operator makes them")
    func billingClaimsAreSourced() throws {
        // The National Domestic Abuse Helpline is free, but neither it nor Refuge says
        // the call is absent from an itemised bill. Claiming so could expose someone
        // whose abuser checks their phone.
        #expect(try service("national-domestic-abuse-helpline").billingNote == nil)
        #expect(try service("samaritans").billingNote != nil)
    }
}

@Suite("Content pack: 999 guidance")
struct EmergencyGuidanceTests {

    @Test("The Silent Solution guidance debunks the viral version and says what happens if you don't press 55")
    func silentSolution() throws {
        let detail = try route("silent-solution-55").detail.lowercased()
        // IOPC: "It is not true that police will automatically attend if you make a
        // silent 999 call." The 2023 build repeated the myth.
        #expect(detail.contains("does not automatically bring police"))
        #expect(detail.contains("does not let the police find"))
        #expect(detail.contains("mobile"))
        // If 55 is not pressed the call is terminated. Someone relying on silence
        // alone must know that.
        #expect(detail.contains("the call ends"))
    }

    @Test("Advanced Mobile Location is described as an attempt, never a guarantee")
    func amlIsNotOverstated() throws {
        // Apple says the iPhone "will attempt to send" location, carrier by carrier.
        // "The police can see where you are" is exactly the false reassurance to avoid.
        let detail = try route("voice-999").detail.lowercased()
        #expect(detail.contains("tries to send"))
        #expect(!detail.contains("police can see"))
    }

    @Test("Text-to-999 states its registration requirement and that the app cannot do it")
    func textTo999() throws {
        let prerequisite = try #require(try route("text-999").prerequisite).lowercased()
        #expect(prerequisite.contains("register"))
        #expect(prerequisite.contains("cannot"))
    }

    @Test("18000 is a number you call, never one you text")
    func relayUK() throws {
        #expect(try route("relay-uk-18000").detail.contains("not one you text"))
    }
}

@Suite("Content pack: Apple safety features")
struct SafetyGuideTests {

    @Test("Emergency SOS does not claim five presses works by default")
    func emergencySOS() throws {
        // The 2023 app told users to "press the lock button FIVE times". That only
        // works once "Call with 5 Presses" has been switched on.
        let summary = try guide("emergency-sos").summary
        #expect(summary.contains("Call with 5 Presses"))
        #expect(summary.lowercased().contains("only works"))
    }

    @Test("Medical ID warns that Show When Locked exposes emergency contacts")
    func medicalID() throws {
        let caution = try #require(try guide("medical-id").caution).lowercased()
        #expect(caution.contains("show when locked"))
        #expect(caution.contains("without your passcode"))
    }

    @Test("Check In states that both people need iOS 17")
    func checkIn() throws {
        #expect(try guide("check-in").summary.contains("iOS 17"))
    }
}

@Suite("Content pack: links")
struct LinkTests {

    @Test("No content references a dead or hijacked emergency domain")
    func noHostileDomains() throws {
        let everything = try JSONEncoder().encode(try pack())
        let text = String(decoding: everything, as: UTF8.self)
        #expect(!text.contains("emergencysms.org.uk"))
        #expect(!text.contains("emergencysms.net"))
    }

    @Test("Every link and source is https and parses")
    func urlsAreSound() throws {
        let p = try pack()
        let urls = p.services.flatMap { [$0.url, $0.source] }
            + p.emergencyRoutes.compactMap(\.learnMoreURL)
            + p.guides.map(\.url)
        for url in urls {
            #expect(url.hasPrefix("https://"), "Not https: \(url)")
            #expect(URL(string: url) != nil, "Unparseable: \(url)")
        }
    }
}
