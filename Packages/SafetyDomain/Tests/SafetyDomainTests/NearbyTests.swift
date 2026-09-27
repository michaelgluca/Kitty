import Foundation
import Testing

@testable import SafetyDomain

@Suite("Distance")
struct DistanceTests {

    @Test("One degree of latitude is about 111 km")
    func oneDegree() {
        let metres = Distance.metres(from: Coordinate(latitude: 51, longitude: 0), to: Coordinate(latitude: 52, longitude: 0))
        #expect(abs(metres - 111_195) < 5)
    }

    @Test("The same point is zero, and distance is symmetric")
    func zeroAndSymmetric() {
        let a = Coordinate(latitude: 51.5, longitude: -0.12)
        let b = Coordinate(latitude: 53.8, longitude: -1.55)
        #expect(Distance.metres(from: a, to: a) == 0)
        #expect(abs(Distance.metres(from: a, to: b) - Distance.metres(from: b, to: a)) < 0.001)
    }
}

@Suite("Nearest places")
struct NearestPlacesTests {

    private let origin = Coordinate(latitude: 51.5, longitude: -0.12)

    private func place(_ id: String, _ lat: Double, _ lon: Double) -> NearbyPlace {
        NearbyPlace(id: id, name: id, coordinate: Coordinate(latitude: lat, longitude: lon), phone: nil)
    }

    @Test("Orders nearest first")
    func ordering() {
        let far = place("far", 51.6, -0.12)
        let near = place("near", 51.501, -0.12)
        let middle = place("middle", 51.52, -0.12)
        #expect([far, near, middle].nearestFirst(from: origin).map(\.id) == ["near", "middle", "far"])
    }

    @Test("Drops a place at null island rather than listing it")
    func dropsNullIsland() {
        // Map data can carry (0, 0). Sorted by distance it would simply be last; shown,
        // it would be a police station in the Gulf of Guinea.
        let ghost = place("ghost", 0, 0)
        #expect([ghost, place("real", 51.51, -0.12)].nearestFirst(from: origin).map(\.id) == ["real"])
    }
}

@Suite("Reads as a police station")
struct ReadsAsPoliceStationTests {

    @Test(
        "Real police stations are kept",
        arguments: [
            "Charing Cross Police Station",
            "Police Scotland Glasgow City Centre Police Office",
            "PSNI Musgrave Station",
        ]
    )
    func keepsRealStations(name: String) {
        #expect(readsAsPoliceStation(name: name))
    }

    @Test(
        "Welsh-named and PSNI-named stations are kept, so a nearer one is never hidden behind a farther one",
        arguments: [
            "Gorsaf Heddlu Caerdydd",
            "Cardiff Bay Police Station / Gorsaf Heddlu Bae Caerdydd",
            // The article form is common in Welsh signage: "heddlu" and "gorsaf"
            // together, not necessarily side by side.
            "Gorsaf yr Heddlu Aberystwyth",
            "Police Service of Northern Ireland Lisburn",
            "Police Service of Northern Ireland \u{2013} Lisburn",
        ]
    )
    func keepsWelshAndNorthernIrishStations(name: String) {
        #expect(readsAsPoliceStation(name: name))
    }

    @Test(
        "Either Welsh word alone is not enough: \"gorsaf\" is any station, \"heddlu\" is the force",
        arguments: [
            "Gorsaf Caerdydd Canolog",
            "Heddlu De Cymru Headquarters",
        ]
    )
    func rejectsHalfOfTheWelshName(name: String) {
        #expect(!readsAsPoliceStation(name: name))
    }

    @Test(
        "A name that reads as a station but is not a working one is rejected, before any accept rule",
        arguments: [
            "Police Station Museum",
            "The Old Police Station",
            "Former Police Station",
            "Closed Police Station",
            "Police Station (closed)",
            "Amgueddfa Gorsaf Heddlu",
            "Police Station Telephone Box",
            "Police Box by Earls Court Police Station",
            "Police Station Phone Box",
        ]
    )
    func rejectsNamesThatAreNotAWorkingStation(name: String) {
        #expect(!readsAsPoliceStation(name: name))
    }

    @Test(
        "Reject words are matched as whole words, so a real station is not hidden by a place name that contains one",
        arguments: [
            "Bold Police Station",
            "Boxmoor Police Station",
            "Enclosed Lane Police Station",
        ]
    )
    func rejectWordsAreWholeWords(name: String) {
        #expect(readsAsPoliceStation(name: name))
    }

    @Test(
        "Places that merely share the .police category are rejected",
        arguments: [
            "Crime Museum",
            "Telephone Box",
            "Police Box",
            "Police Federation",
        ]
    )
    func rejectsNonStations(name: String) {
        #expect(!readsAsPoliceStation(name: name))
    }

    @Test("An empty or missing name is rejected, not treated as a match")
    func rejectsEmptyOrMissingName() {
        #expect(!readsAsPoliceStation(name: ""))
        #expect(!readsAsPoliceStation(name: nil))
    }

    @Test("Matching is case-insensitive")
    func caseInsensitive() {
        #expect(readsAsPoliceStation(name: "CHARING CROSS POLICE STATION"))
        #expect(readsAsPoliceStation(name: "psni musgrave station"))
    }
}
