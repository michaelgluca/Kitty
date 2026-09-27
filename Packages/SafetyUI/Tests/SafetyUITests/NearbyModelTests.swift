import Foundation
import SafetyContent
import SafetyDomain
import SafetyServices
import SafetyTesting
import Testing

@testable import SafetyUI

private let here = Coordinate(latitude: 51.5033, longitude: -0.1196)
private let fix = LocationFix(coordinate: here, horizontalAccuracy: 10, timestamp: Date())

private func station(_ id: String, north metres: Double) -> NearbyPlace {
    NearbyPlace(id: id, name: id, coordinate: Coordinate(latitude: here.latitude + metres / 111_195, longitude: here.longitude), phone: nil)
}

private let route = WalkingRoute(distanceMetres: 450, expectedSeconds: 360, path: [here, station("a", north: 400).coordinate])

@MainActor
@Suite("Nearby model")
struct NearbyModelTests {

    private func services(
        location: any LocationProviding = StubLocationProvider(fix: fix),
        places: StubPlaceSearch = StubPlaceSearch([.found([station("a", north: 400)])]),
        routes: any RouteFinding = StubRouteFinder(.found(route)),
        maps: SpyMapsOpener = SpyMapsOpener(),
        area: GeocodedArea? = GeocodedArea(countryCode: "GB", names: ["England"])
    ) -> Services {
        var s = Services.unavailable
        s.location = location
        s.places = places
        s.routes = routes
        s.maps = maps
        s.areas = StubAreaNamer(area)
        return s
    }

    @Test("Each location state is its own visible state, and none of them prompts or searches", arguments: [
        (LocationAuthorization.notDetermined, NearbyModel.State.needsPermission),
        (.denied, .locationOff),
        (.restricted, .locationRestricted),
        (.authorizedReducedAccuracy, .locationApproximate),
    ])
    func locationStates(authorization: LocationAuthorization, expected: NearbyModel.State) async {
        let location = StubLocationProvider(authorization: authorization, fix: fix)
        let places = StubPlaceSearch([.found([station("a", north: 400)])])
        let m = NearbyModel(services: services(location: location, places: places))
        await m.refresh()
        #expect(m.state == expected)
        #expect(location.authorizationRequestCount == 0)
        #expect(location.fixRequestCount == 0)
        #expect(places.requestedRadii.isEmpty)
    }

    @Test("Finds the nearest station, with a walking route to it and the nation")
    func finds() async throws {
        let m = NearbyModel(services: services(places: StubPlaceSearch([.found([station("far", north: 1_500), station("near", north: 300)])])))
        await m.refresh()
        guard case let .found(found) = m.state else { Issue.record("Expected found, got \(m.state)"); return }
        #expect(found.stations.map(\.id) == ["near", "far"])
        #expect(found.route == route)
        #expect(found.origin == here)
        #expect(m.detectedNation == .england)
    }

    @Test("Shows at most five stations")
    func caps() async {
        let many = (1...9).map { station("s\($0)", north: Double($0) * 100) }
        let m = NearbyModel(services: services(places: StubPlaceSearch([.found(many)])))
        await m.refresh()
        guard case let .found(found) = m.state else { Issue.record("Expected found"); return }
        #expect(found.stations.count == NearbyModel.maximumStations)
    }

    @Test("Widens the search in steps before saying there is nothing nearby")
    func widens() async {
        let places = StubPlaceSearch([.noneFound, .noneFound, .found([station("a", north: 20_000)])])
        let m = NearbyModel(services: services(places: places))
        await m.refresh()
        #expect(places.requestedRadii == NearbyModel.searchRadii)
        guard case .found = m.state else { Issue.record("Expected found"); return }
    }

    @Test("Says how far it looked when nothing is found")
    func noneFound() async {
        let m = NearbyModel(services: services(places: StubPlaceSearch([])))
        await m.refresh()
        #expect(m.state == .noneFound(searchedMetres: 25_000))
    }

    @Test("A search that cannot run is reported as such, not as nothing nearby, and is not retried wider")
    func searchFails() async {
        let places = StubPlaceSearch([.failed])
        let m = NearbyModel(services: services(places: places))
        await m.refresh()
        #expect(m.state == .searchFailed)
        #expect(places.requestedRadii.count == 1)
    }

    @Test("Results that are all at null island count as nothing found at that radius")
    func onlyGhosts() async {
        let ghost = NearbyPlace(id: "ghost", name: nil, coordinate: Coordinate(latitude: 0, longitude: 0), phone: nil)
        let places = StubPlaceSearch([.found([ghost]), .found([station("real", north: 5_000)])])
        let m = NearbyModel(services: services(places: places))
        await m.refresh()
        guard case let .found(found) = m.state else { Issue.record("Expected found"); return }
        #expect(found.stations.map(\.id) == ["real"])
    }

    @Test("Without a route the stations are still shown")
    func routeFails() async {
        let m = NearbyModel(services: services(routes: StubRouteFinder(.failed)))
        await m.refresh()
        guard case let .found(found) = m.state else { Issue.record("Expected found"); return }
        #expect(found.route == nil)
        #expect(found.stations.count == 1)
    }

    @Test("No fix means a visible state, and no search from a made-up place")
    func noFix() async {
        let places = StubPlaceSearch([.found([station("a", north: 400)])])
        let m = NearbyModel(services: services(location: StubLocationProvider(fix: nil), places: places))
        await m.refresh()
        #expect(m.state == .noLocation)
        #expect(places.requestedRadii.isEmpty)
    }

    @Test("A provider that never answers ends in noLocation on time", .timeLimit(.minutes(1)))
    func hungProvider() async {
        let hanging = HangingLocationProvider()
        let m = NearbyModel(services: services(location: hanging), locationTimeout: .milliseconds(200))
        let clock = ContinuousClock()
        let start = clock.now
        await m.refresh()
        #expect(m.state == .noLocation)
        #expect(clock.now - start < .seconds(3))
        hanging.release()
    }

    @Test("An unknown or non-UK area leaves the nation for the person to choose")
    func unknownNation() async {
        let m = NearbyModel(services: services(area: nil))
        await m.refresh()
        #expect(m.detectedNation == nil)
        let abroad = NearbyModel(services: services(area: GeocodedArea(countryCode: "FR", names: ["Île-de-France"])))
        await abroad.refresh()
        #expect(abroad.detectedNation == nil)
    }

    @Test("A nation detected on an earlier refresh is cleared, not left stale, when a later refresh finds none")
    func staleNationIsCleared() async {
        let places = StubPlaceSearch([.found([station("a", north: 400)]), .found([station("a", north: 400)])])
        var s = services(places: places)
        s.areas = TogglingAreaNamer(first: GeocodedArea(countryCode: "GB", names: ["Scotland"]), rest: nil)
        let m = NearbyModel(services: s)

        await m.refresh()
        #expect(m.detectedNation == .scotland)

        await m.refresh()
        #expect(m.detectedNation == nil)
    }

    @Test("A stale nation from an earlier refresh is cleared when location becomes unavailable")
    func staleNationClearedWhenLocationLost() async {
        let location = MutableAuthorizationLocationProvider(fix: fix)
        let m = NearbyModel(services: services(location: location))
        await m.refresh()
        #expect(m.detectedNation == .england)

        location.authorization = .denied
        await m.refresh()
        #expect(m.state == .locationOff)
        #expect(m.detectedNation == nil)
    }

    @Test("Allowing location asks once, then searches")
    func allow() async {
        let location = StubLocationProvider(authorization: .notDetermined, authorizationAfterRequest: .authorizedWhenInUse, fix: fix)
        let m = NearbyModel(services: services(location: location))
        await m.allowLocation()
        #expect(location.authorizationRequestCount == 1)
        guard case .found = m.state else { Issue.record("Expected found"); return }
    }

    @Test("Directions go to Apple Maps, and a failure to open is reported")
    func directions() async {
        let spy = SpyMapsOpener()
        let m = NearbyModel(services: services(maps: spy))
        let target = station("a", north: 400)
        await m.openDirections(to: target)
        #expect(spy.opened == [target])
        #expect(!m.directionsFailed)

        let failing = NearbyModel(services: services(maps: SpyMapsOpener(succeeds: false)))
        await failing.openDirections(to: target)
        #expect(failing.directionsFailed)
    }
}

/// A location provider whose authorization can change between calls, so a test can
/// show a person losing location access between two refreshes. `StubLocationProvider`
/// deliberately has no such setter — its authorization models what CoreLocation
/// reports at the moment of the call, fixed for the life of the double — so this
/// stays local to this test rather than widening that double for one scenario.
private final class MutableAuthorizationLocationProvider: LocationProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _authorization: LocationAuthorization
    private let fix: LocationFix?

    init(authorization: LocationAuthorization = .authorizedWhenInUse, fix: LocationFix?) {
        self._authorization = authorization
        self.fix = fix
    }

    @MainActor var authorization: LocationAuthorization {
        get { lock.withLock { _authorization } }
        set { lock.withLock { _authorization = newValue } }
    }

    @MainActor func requestWhenInUseAuthorization() async -> LocationAuthorization { authorization }
    @MainActor func currentFix(timeout: Duration) async -> LocationFix? { fix }
}

/// Answers the first call with one area, then another for every call after —
/// so a test can show a nation detected on one refresh going stale on the next.
private final class TogglingAreaNamer: AreaNaming, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private let first: GeocodedArea?
    private let rest: GeocodedArea?

    init(first: GeocodedArea?, rest: GeocodedArea?) {
        self.first = first
        self.rest = rest
    }

    @MainActor
    func area(at coordinate: Coordinate) async -> GeocodedArea? {
        let count = lock.withLock { () -> Int in
            _callCount += 1
            return _callCount
        }
        return count == 1 ? first : rest
    }
}
