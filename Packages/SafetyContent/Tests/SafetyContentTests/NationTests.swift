import Foundation
import SafetyDomain
import Testing

@testable import SafetyContent

@Suite("Nation from a geocoded area")
struct NationTests {

    @Test("A region name that is a nation is read directly", arguments: [
        ("England", Nation.england), ("Wales", .wales), ("Scotland", .scotland), ("Northern Ireland", .northernIreland),
        ("england", .england), ("  Scotland ", .scotland),
    ])
    func regionName(name: String, nation: Nation) {
        #expect(Nation(area: GeocodedArea(countryCode: "GB", names: [name])) == nation)
    }

    @Test("A full address is read by its last part only")
    func lastPart() {
        #expect(Nation(area: GeocodedArea(countryCode: "GB", names: ["Glasgow G1 1AA, Scotland"])) == .scotland)
        // A street named after another nation must not decide it.
        #expect(Nation(area: GeocodedArea(countryCode: "GB", names: ["1 Princess of Wales Road, London, England"])) == .england)
        #expect(Nation(area: GeocodedArea(countryCode: "GB", names: ["2 Wales Road, Leeds"])) == nil)
    }

    @Test("The first name that decides it wins")
    func firstDecides() {
        #expect(Nation(area: GeocodedArea(countryCode: "GB", names: ["Greater London", "London, England"])) == .england)
    }

    @Test("Outside the UK, or when the country is unknown, there is no nation — never a guess")
    func notUK() {
        #expect(Nation(area: GeocodedArea(countryCode: "AU", names: ["New South Wales"])) == nil)
        #expect(Nation(area: GeocodedArea(countryCode: nil, names: ["England"])) == nil)
        #expect(Nation(area: GeocodedArea(countryCode: "GB", names: [])) == nil)
    }

    @Test("The country code is read case-insensitively")
    func countryCase() {
        #expect(Nation(area: GeocodedArea(countryCode: "gb", names: ["Wales"])) == .wales)
    }
}
