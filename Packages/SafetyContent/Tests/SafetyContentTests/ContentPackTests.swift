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
        #expect(p.version == 5)
        #expect(!p.services.isEmpty && !p.emergencyRoutes.isEmpty && !p.guides.isEmpty)
    }

    @Test("Carries the UK emergency number as data, for the confirmed 999 button")
    func emergencyNumber() throws {
        let pack = try ContentLoader.loadUK()
        #expect(pack.emergencyNumber == "999")
        #expect(PhoneNumber(pack.emergencyNumber)?.dialable == "999")
    }

    @Test("Identifiers are unique within each section")
    func uniqueIDs() throws {
        let p = try pack()
        let reporting = p.reporting(for: .unitedKingdom)
        #expect(Set(reporting.map(\.id)).count == reporting.count)
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
        let p = try pack()
        for s in p.services + p.refuges {
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
        let p = try pack()
        for s in p.services + p.refuges {
            guard let phone = s.phone, let dialable = PhoneNumber(phone)?.dialable else { continue }
            #expect(!forbidden.contains(dialable), "\(s.id) carries emergency short code \(dialable)")
        }
    }

    @Test("Numbers are shown in readable groups, not as an unbroken string of digits")
    func readable() throws {
        // "08085002222" is hard to read under stress and easy to misdial by hand.
        let p = try pack()
        for s in p.services + p.refuges {
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
        let caution = try #require(try guide("emergency-contacts-and-medical-id").caution).lowercased()
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
        // Built in steps: as one expression it is too much for the type checker.
        var urls: [String] = (p.services + p.reporting(for: .unitedKingdom) + p.refuges).flatMap { [$0.url, $0.source] }
        urls += p.emergencyRoutes.compactMap(\.learnMoreURL)
        urls += p.guides.map(\.url)
        urls += p.rights.flatMap { $0.sources.map(\.url) }
        urls.append(p.refugeNote.source.url)
        for url in urls {
            #expect(url.hasPrefix("https://"), "Not https: \(url)")
            #expect(URL(string: url) != nil, "Unparseable: \(url)")
        }
    }

    @Test("Every URL a person can open is in allURLs, including rights sources and refuge routes")
    func allURLsIsComplete() throws {
        let p = try pack()
        let listed = Set(ContentLoader.allURLs(in: p))
        let expected = Set(p.rights.flatMap { $0.sources.map(\.url) } + p.refuges.map(\.url) + [p.refugeNote.source.url])
        #expect(expected.isSubset(of: listed), "Missing: \(expected.subtracting(listed))")
    }
}

@Suite("Content pack: crime reporting")
struct CrimeReportingTests {

    private func reporting() throws -> [SupportService] { try pack().reporting(for: .unitedKingdom) }
    private func route(_ id: String) throws -> SupportService {
        try #require(try reporting().first { $0.id == id }, "No reporting route \(id)")
    }

    @Test("Reporting routes are withheld entirely outside the UK")
    func hiddenOutsideUK() throws {
        // App Store Review Guideline 1.7: apps for reporting alleged criminal activity
        // "can only be offered in countries or regions where such involvement is
        // present". These routes involve only UK police, so outside the UK they are
        // not shown at all — a caveat is not enough.
        #expect(try pack().reporting(for: .elsewhere(countryCode: "US")).isEmpty)
        #expect(try pack().reporting(for: .elsewhere(countryCode: nil)).isEmpty)
    }

    @Test("Reporting routes are shown in the UK")
    func shownInUK() throws {
        #expect(!(try reporting()).isEmpty)
    }

    @Test("Every reporting route is marked as reporting")
    func kind() throws {
        for r in try reporting() { #expect(r.kind == .reporting, "\(r.id)") }
    }

    @Test("British Transport Police covers Great Britain, not the UK")
    func btpCoverage() throws {
        // BTP does not police Northern Ireland. Labelling it UK-wide would send someone
        // in Belfast to a force that cannot help them.
        #expect(try route("british-transport-police").coverage == .greatBritain)
    }

    @Test("61016 is a text number, and BTP's voice line is separate")
    func btpNumbers() throws {
        // 61016 is text-only. In the `phone` field it would become a call button.
        let btp = try route("british-transport-police")
        #expect(PhoneNumber(try #require(btp.textNumber))?.dialable == "61016")
        #expect(PhoneNumber(try #require(btp.phone))?.dialable == "0800405040")
        #expect(btp.phone != btp.textNumber)
    }

    @Test("Every text number carries a note about cost or failure")
    func textNotes() throws {
        let p = try pack()
        for s in p.services + p.reporting(for: .unitedKingdom) where s.textNumber != nil {
            #expect(s.textNote != nil, "\(s.id) offers a text number with no warning")
        }
    }

    @Test("No reporting route carries an emergency number as a call or text")
    func noEmergencyNumbers() throws {
        // Reporting is for when nobody is in danger. 999 and 112 belong in the
        // emergency routes, behind their own guidance.
        let forbidden: Set = ["999", "112"]
        for r in try reporting() {
            for raw in [r.phone, r.textNumber].compactMap({ $0 }) {
                #expect(!forbidden.contains(PhoneNumber(raw)?.dialable ?? ""), "\(r.id) carries \(raw)")
            }
        }
    }

    @Test("StreetSafe is never presented as a way to report a crime")
    func streetSafe() throws {
        // police.uk: "StreetSafe is not for reporting crimes." And because it is
        // anonymous, nobody can come back to the person who used it.
        let summary = try route("streetsafe").summary.lowercased()
        #expect(summary.contains("not for reporting a crime"))
        #expect(summary.contains("anonymous"))
    }

    @Test("101 is not claimed to be open at any hour")
    func oneOhOneHours() throws {
        // Neither police.uk nor GOV.UK states 101's hours, so the app must not say
        // "24/7".
        #expect(try route("police-101").availability != .allHours)
    }

    @Test("Crimestoppers is open at any hour and is said not to be the police")
    func crimestoppers() throws {
        let c = try route("crimestoppers")
        #expect(c.availability == .allHours)
        #expect(c.summary.lowercased().contains("not the police"))
    }

    @Test("Project Guardian is not offered — it is now a schools workshop")
    func noProjectGuardian() throws {
        // The 2023 dissertation cited the 2013 policing operation. The name now
        // belongs to a Year 9 workshop run by the London Transport Museum.
        let text = String(decoding: try JSONEncoder().encode(try pack()), as: UTF8.self).lowercased()
        #expect(!text.contains("project guardian"))
    }
}
