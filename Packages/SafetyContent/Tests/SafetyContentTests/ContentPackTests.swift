import Foundation
import Testing

@testable import SafetyContent

// Content here is treated as code. Each of these pins a fact that was verified
// against the issuing body and that would cause real harm if it regressed — most of
// them are mistakes the 2023 build actually shipped.

@Suite("UK content pack")
struct ContentPackTests {

    private func pack() throws -> ContentPack { try ContentLoader.loadUK() }

    @Test("Loads and is not empty")
    func loads() throws {
        let pack = try pack()
        #expect(pack.version == 1)
        #expect(!pack.services.isEmpty)
        #expect(!pack.emergencyRoutes.isEmpty)
    }

    @Test("Identifiers are unique")
    func uniqueIDs() throws {
        let pack = try pack()
        #expect(Set(pack.services.map(\.id)).count == pack.services.count)
        #expect(Set(pack.emergencyRoutes.map(\.id)).count == pack.emergencyRoutes.count)
    }

    @Test("Women's Aid carries no phone number, because it has no telephone helpline")
    func womensAidHasNoPhone() throws {
        let service = try #require(try pack().services.first { $0.id == "womens-aid" })
        #expect(service.phone == nil)
    }

    @Test("England-only services are not described as UK-wide")
    func coverageIsHonest() throws {
        let pack = try pack()
        let nationalDA = try #require(pack.services.first { $0.id == "national-domestic-abuse-helpline" })
        #expect(nationalDA.coverage == .england)

        let rapeCrisis = try #require(pack.services.first { $0.id == "rape-crisis-support-line" })
        #expect(rapeCrisis.coverage == .englandAndWales)
    }

    @Test("The Silent Solution entry debunks the viral version rather than repeating it")
    func silentSolutionIsCorrect() throws {
        let route = try #require(try pack().emergencyRoutes.first { $0.id == "silent-solution-55" })
        let detail = route.detail.lowercased()

        // The IOPC states plainly that a silent 999 call does not bring police, and
        // that 55 does not let them track you. The 2023 build repeated the myth.
        #expect(detail.contains("does not automatically bring police"))
        #expect(detail.contains("does not let police track you"))
        #expect(detail.contains("mobile"))
    }

    @Test("Text-to-999 states the registration requirement and does not claim the app can do it")
    func textTo999StatesRegistration() throws {
        let route = try #require(try pack().emergencyRoutes.first { $0.id == "text-999" })
        let prerequisite = try #require(route.prerequisite).lowercased()
        #expect(prerequisite.contains("register"))
        // iOS cannot read the inbound confirmation SMS, so claiming a user is
        // registered would be a lie they might rely on.
        #expect(prerequisite.contains("cannot"))
    }

    @Test("18000 is described as a number you call, never one you text")
    func relayUKIsACall() throws {
        let route = try #require(try pack().emergencyRoutes.first { $0.id == "relay-uk-18000" })
        #expect(route.detail.contains("not one you text"))
    }

    @Test("No content references a dead or hijacked emergency domain")
    func noHostileDomains() throws {
        // emergencysms.org.uk was taken over and now serves a gambling affiliate
        // site; emergencysms.net is dead. Both are still linked from UK police and
        // fire service pages, so a well-meaning edit could reintroduce them.
        let pack = try pack()
        let everything = ContentLoader.allURLs(in: pack).joined(separator: " ")
            + pack.emergencyRoutes.map(\.detail).joined(separator: " ")
        #expect(!everything.contains("emergencysms.org.uk"))
        #expect(!everything.contains("emergencysms.net"))
    }

    @Test("Every URL is https and parses")
    func urlsAreSound() throws {
        for url in ContentLoader.allURLs(in: try pack()) {
            #expect(url.hasPrefix("https://"), "Not https: \(url)")
            #expect(URL(string: url) != nil, "Unparseable: \(url)")
        }
    }

    @Test("Round-trips through JSON without losing anything")
    func roundTrips() throws {
        let original = try pack()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ContentPack.self, from: data)
        #expect(decoded == original)
    }

    @Test("Availability decodes from both the bare-string and object forms")
    func availabilityForms() throws {
        let pack = try pack()
        let samaritans = try #require(pack.services.first { $0.id == "samaritans" })
        #expect(samaritans.availability == .allHours)

        let womensAid = try #require(pack.services.first { $0.id == "womens-aid" })
        #expect(womensAid.availability == .weekdays(openHour: 10, closeHour: 16))
    }
}
