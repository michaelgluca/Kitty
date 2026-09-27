import Foundation
import SafetyDomain
import Testing

@testable import SafetyUI

@Suite("Nearby copy")
struct NearbyCopyTests {

    @Test("Every state that needs words has real words", arguments: [
        NearbyModel.State.needsPermission, .locationOff, .locationRestricted, .locationApproximate,
        .locating, .noLocation, .searching, .noneFound(searchedMetres: 25_000), .searchFailed,
    ])
    func stateCopy(state: NearbyModel.State) throws {
        let text = try #require(NearbyCopy.message(for: state))
        #expect(text.contains(" "), "Unresolved copy for \(state): \(text)")
    }

    @Test("Approximate location is called out as not precise enough")
    func approximate() throws {
        #expect(try #require(NearbyCopy.message(for: .locationApproximate)).contains("Precise Location"))
    }

    @Test("A failed search is never described as nothing nearby")
    func failedIsNotNone() throws {
        let failed = try #require(NearbyCopy.message(for: .searchFailed))
        #expect(!failed.contains("No police stations"))
    }

    @Test("Nothing found says how far it looked")
    func noneFoundSaysHowFar() throws {
        let text = try #require(NearbyCopy.message(for: .noneFound(searchedMetres: 25_000)))
        #expect(text.contains(NearbyCopy.distance(25_000)))
    }

    @Test("Road distances follow the locale: miles in the UK, kilometres in France")
    func distanceUnits() {
        #expect(NearbyCopy.distance(1_609.344, locale: Locale(identifier: "en_GB")).contains("mi"))
        #expect(NearbyCopy.distance(1_000, locale: Locale(identifier: "fr_FR")).contains("km"))
    }

    @Test("Walking time is in minutes")
    func walk() {
        #expect(NearbyCopy.walk(360).contains("6"))
    }

    @Test("Every Nearby key resolves", arguments: [
        "nearby.police.header", "nearby.police.footer.uk", "nearby.police.footer.elsewhere",
        "nearby.retry", "nearby.station.unnamed", "nearby.station.distance", "nearby.route.walk",
        "nearby.route.unavailable", "nearby.directions", "nearby.directions.hint", "nearby.directionsFailed",
        "nearby.map.label", "nearby.refuges.link", "nearby.refuges.detail",
        "refuges.title", "refuges.why.header", "refuges.nation.header", "refuges.nation.choose",
        "refuges.nation.fromLocation", "refuges.nation.prompt", "refuges.list.header",
    ])
    func keysResolve(key: String) {
        #expect(Strings.localized(String.LocalizationValue(key)) != key, "Missing catalogue entry: \(key)")
    }

    @Test("The UK footer names 999; the footer elsewhere does not")
    func footers() {
        #expect(Strings.localized("nearby.police.footer.uk").contains("999"))
        #expect(!Strings.localized("nearby.police.footer.elsewhere").contains("999"))
    }
}
