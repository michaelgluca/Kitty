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
    func finds() async {
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

    @Test(
        "A nation lookup that never answers times out to no nation, without delaying the search, and a later refresh can still find one",
        .timeLimit(.minutes(1))
    )
    func nationLookupTimesOut() async {
        let hanging = HangingAreaNamer()
        var s = services()
        s.areas = hanging
        let m = NearbyModel(services: s, nationLookupTimeout: .milliseconds(200))

        let clock = ContinuousClock()
        let start = clock.now
        await m.refresh()
        #expect(clock.now - start < .seconds(3))
        guard case .found = m.state else { Issue.record("Expected found, got \(m.state)"); return }
        #expect(m.detectedNation == nil)

        hanging.reply.open(with: GeocodedArea(countryCode: "GB", names: ["England"]))
        await m.refresh()
        #expect(m.detectedNation == .england)
    }

    @Test(
        "A search step that never answers times out to a visible failure, not a wider retry, and a later refresh can still succeed",
        .timeLimit(.minutes(1))
    )
    func searchStepTimesOut() async {
        let hanging = HangingPlaceSearch()
        var s = services()
        s.places = hanging
        let m = NearbyModel(services: s, searchStepTimeout: .milliseconds(200))

        let clock = ContinuousClock()
        let start = clock.now
        await m.refresh()
        #expect(clock.now - start < .seconds(3))
        #expect(m.state == .searchFailed)
        #expect(hanging.requestedRadii.count == 1)

        hanging.reply.open(with: .found([station("a", north: 400)]))
        await m.refresh()
        guard case .found = m.state else { Issue.record("Expected found after retry, got \(m.state)"); return }
    }

    @Test(
        "A route lookup that never answers times out without hiding the station, and a later refresh can still get one",
        .timeLimit(.minutes(1))
    )
    func routeTimesOut() async {
        let hanging = HangingRouteFinder()
        // Two scripted finds: one for the timed-out first refresh, one for the retry —
        // `StubPlaceSearch` answers each `refresh()` in turn, not just the first.
        let places = StubPlaceSearch([.found([station("a", north: 400)]), .found([station("a", north: 400)])])
        let m = NearbyModel(services: services(places: places, routes: hanging), routeTimeout: .milliseconds(200))

        let clock = ContinuousClock()
        let start = clock.now
        await m.refresh()
        #expect(clock.now - start < .seconds(3))
        guard case let .found(found) = m.state else { Issue.record("Expected found, got \(m.state)"); return }
        #expect(found.route == nil)
        #expect(found.stations.count == 1)

        hanging.reply.open(with: .found(route))
        await m.refresh()
        guard case let .found(retryFound) = m.state else { Issue.record("Expected found after retry, got \(m.state)"); return }
        #expect(retryFound.route == route)
    }

    @Test("A second refresh while one is already searching does nothing, and the first still finishes", .timeLimit(.minutes(1)))
    func doubleRefresh() async {
        let hanging = HangingPlaceSearch()
        var s = services()
        s.places = hanging
        let m = NearbyModel(services: s)

        let first = Task { await m.refresh() }
        // Wait for the actual request, not just the `.searching` state: the state
        // flips synchronously the moment the fix arrives, a moment before the search
        // loop's first `firstResult` call actually reaches the double.
        for _ in 0..<10_000 where hanging.requestedRadii.isEmpty { await Task.yield() }
        #expect(m.state == .searching)
        #expect(m.isBusy)

        // A second call made while the first is still stuck in the search must not
        // issue its own request, or two searches would race.
        await m.refresh()
        #expect(hanging.requestedRadii.count == 1)

        hanging.reply.open(with: .found([station("a", north: 400)]))
        await first.value
        guard case .found = m.state else { Issue.record("Expected found"); return }
    }

    @Test(
        "A nation lookup left over from an old refresh, still pending after the state moved past it, never overwrites a newer refresh's answer",
        .timeLimit(.minutes(1))
    )
    func staleNationLookupNeverOverwritesANewerOne() async {
        // Wales is what the *second* refresh's own lookup answers, immediately.
        // Scotland is what the *first* refresh's lookup eventually answers, late —
        // after the second refresh has already finished. Without the refresh
        // generation check, Scotland would land last and stomp Wales.
        let namer = SequencedAreaNamer(subsequent: GeocodedArea(countryCode: "GB", names: ["Wales"]))
        let places = StubPlaceSearch([.found([station("a", north: 400)]), .found([station("a", north: 400)])])
        var s = services(places: places)
        s.areas = namer
        let m = NearbyModel(services: s)

        let first = Task { await m.refresh() }
        for _ in 0..<10_000 {
            if case .found = m.state { break }
            await Task.yield()
        }
        guard case .found = m.state else { Issue.record("Expected the first refresh to reach found"); return }

        // The first refresh's own nation lookup (Scotland, below) is still stuck:
        // this is a second, independent refresh, not the guard from the previous
        // test — `state` already being terminal is exactly what makes it possible.
        await m.refresh()
        #expect(m.detectedNation == .wales)

        namer.firstReply.open(with: GeocodedArea(countryCode: "GB", names: ["Scotland"]))
        await first.value
        #expect(m.detectedNation == .wales)
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

    @Test("Being declined when allowing location ends in locationOff, not stuck locating")
    func allowDeclined() async {
        let location = StubLocationProvider(authorization: .notDetermined, authorizationAfterRequest: .denied, fix: fix)
        let m = NearbyModel(services: services(location: location))
        await m.allowLocation()
        #expect(location.authorizationRequestCount == 1)
        #expect(m.state == .locationOff)
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

// MARK: - Staying current

private let fixedAtStart = Date(timeIntervalSinceReferenceDate: 812_000_000)

/// A result that is stale at `now`, or not, by the model's own rule.
private func found(fixedAt: Date) -> NearbyModel.Found {
    NearbyModel.Found(origin: here, fixedAt: fixedAt, stations: [station("a", north: 400)], route: nil)
}

@MainActor
@Suite("Nearby model: staying current")
struct NearbyModelCurrencyTests {

    private func services(
        location: any LocationProviding = StubLocationProvider(fix: fix),
        places: any PlaceSearching = StubPlaceSearch([.found([station("a", north: 400)]), .found([station("b", north: 300)])]),
        time: AdvancingTime = AdvancingTime(fixedAtStart)
    ) -> Services {
        var s = Services.unavailable
        s.location = location
        s.places = places
        s.routes = StubRouteFinder(.found(route))
        s.maps = SpyMapsOpener()
        s.areas = StubAreaNamer(GeocodedArea(countryCode: "GB", names: ["England"]))
        s.time = time
        return s
    }

    @Test("A result records when its location was read, from the injected time source")
    func recordsFixedAt() async {
        let m = NearbyModel(services: services())
        await m.refresh()
        guard case let .found(result) = m.state else { Issue.record("Expected found, got \(m.state)"); return }
        #expect(result.fixedAt == fixedAtStart)
    }

    @Test(
        "A result is current until it reaches the maximum age, then stale; one from the future is stale too, since its age cannot be told",
        arguments: [
            (0.0, false),
            (60.0, false),
            (NearbyModel.resultMaximumAge - 1, false),
            (NearbyModel.resultMaximumAge, true),
            (NearbyModel.resultMaximumAge + 1, true),
            (3 * 60 * 60.0, true),
            (-60.0, true),
        ]
    )
    func stalenessRule(age: TimeInterval, isStale: Bool) {
        #expect(found(fixedAt: fixedAtStart).isStale(at: fixedAtStart + age) == isStale)
    }

    @Test("The maximum age is five minutes")
    func maximumAge() {
        #expect(NearbyModel.resultMaximumAge == 5 * 60)
    }

    @Test("Before anything has run, returning to the tab starts a refresh")
    func idleRefreshes() {
        #expect(NearbyModel(services: services()).shouldRefreshOnReturn)
    }

    @Test("Every state with no result refreshes on return, so a fixed permission or a new signal is picked up", arguments: [
        LocationAuthorization.notDetermined, .denied, .restricted, .authorizedReducedAccuracy,
    ])
    func permissionStatesRefresh(authorization: LocationAuthorization) async {
        let m = NearbyModel(services: services(location: StubLocationProvider(authorization: authorization, fix: fix)))
        await m.refresh()
        #expect(!m.isBusy)
        #expect(m.shouldRefreshOnReturn, "\(m.state) must refresh on return")
    }

    @Test("No fix, nothing found and a failed search all refresh on return")
    func failureStatesRefresh() async {
        let noFix = NearbyModel(services: services(location: StubLocationProvider(fix: nil)))
        await noFix.refresh()
        #expect(noFix.state == .noLocation)
        #expect(noFix.shouldRefreshOnReturn)

        let none = NearbyModel(services: services(places: StubPlaceSearch([])))
        await none.refresh()
        #expect(none.state == .noneFound(searchedMetres: NearbyModel.widestRadius))
        #expect(none.shouldRefreshOnReturn)

        let failed = NearbyModel(services: services(places: StubPlaceSearch([.failed])))
        await failed.refresh()
        #expect(failed.state == .searchFailed)
        #expect(failed.shouldRefreshOnReturn)
    }

    @Test("A current result does not re-search on return; once stale it does, and the new result is timed afresh")
    func staleResultRefreshesOnReturn() async {
        let time = AdvancingTime(fixedAtStart)
        let places = StubPlaceSearch([.found([station("a", north: 400)]), .found([station("b", north: 300)])])
        let m = NearbyModel(services: services(places: places, time: time))
        await m.refresh()
        #expect(places.requestedRadii.count == 1)

        time.advance(by: NearbyModel.resultMaximumAge - 1)
        #expect(!m.shouldRefreshOnReturn)
        await m.refreshIfNeeded()
        #expect(places.requestedRadii.count == 1, "A current result must not re-search every time the tab appears")

        time.advance(by: 1)
        #expect(m.shouldRefreshOnReturn)
        await m.refreshIfNeeded()
        #expect(places.requestedRadii.count == 2, "A stale result must be searched again")
        guard case let .found(result) = m.state else { Issue.record("Expected found, got \(m.state)"); return }
        #expect(result.stations.map(\.id) == ["b"])
        #expect(result.fixedAt == fixedAtStart + NearbyModel.resultMaximumAge)
        #expect(!m.shouldRefreshOnReturn)
    }

    @Test("A failed or empty result is searched again on return", arguments: [PlaceSearchOutcome.failed, .noneFound])
    func failedResultRefreshesOnReturn(first: PlaceSearchOutcome) async {
        let places = StubPlaceSearch([first, .noneFound, .noneFound, .found([station("a", north: 400)])])
        let m = NearbyModel(services: services(places: places))
        await m.refresh()
        let before = places.requestedRadii.count
        await m.refreshIfNeeded()
        #expect(places.requestedRadii.count > before)
    }

    @Test(
        "While a refresh runs, the old result stays on screen marked as updating, never as current, and it goes when the refresh ends",
        .timeLimit(.minutes(1))
    )
    func previousResultWhileUpdating() async {
        let time = AdvancingTime(fixedAtStart)
        let places = HangingPlaceSearch(answeringFirstWith: .found([station("a", north: 400)]))
        let m = NearbyModel(services: services(places: places, time: time))
        await m.refresh()
        guard case let .found(old) = m.state else { Issue.record("Expected found, got \(m.state)"); return }
        #expect(m.previousResult == nil)
        #expect(m.detectedNation == .england)

        time.advance(by: NearbyModel.resultMaximumAge)
        let second = Task { await m.refreshIfNeeded() }
        for _ in 0..<10_000 where places.requestedRadii.count < 2 { await Task.yield() }
        #expect(m.isBusy)
        #expect(m.previousResult == old, "The old result stays visible while updating")
        #expect(m.detectedNation == nil, "A nation from the old reading is not offered as from your location while it is replaced")
        #expect(!m.shouldRefreshOnReturn, "No second refresh while one is running")

        places.reply.open(with: .found([station("b", north: 300)]))
        await second.value
        #expect(m.previousResult == nil)
        guard case let .found(new) = m.state else { Issue.record("Expected found, got \(m.state)"); return }
        #expect(new.stations.map(\.id) == ["b"])
        #expect(m.detectedNation == .england)
    }

    @Test("A refresh that fails replaces the old result with the failure: an old result is never left looking current")
    func failedRefreshDropsOldResult() async {
        let time = AdvancingTime(fixedAtStart)
        let m = NearbyModel(services: services(places: StubPlaceSearch([.found([station("a", north: 400)]), .failed]), time: time))
        await m.refresh()
        guard case .found = m.state else { Issue.record("Expected found, got \(m.state)"); return }

        time.advance(by: NearbyModel.resultMaximumAge)
        await m.refreshIfNeeded()
        #expect(m.state == .searchFailed)
        #expect(m.previousResult == nil)
    }

    @Test("A refresh with no fix replaces the old result too")
    func noFixRefreshDropsOldResult() async {
        let location = MutableAuthorizationLocationProvider(fix: fix)
        let m = NearbyModel(services: services(location: location))
        await m.refresh()
        guard case .found = m.state else { Issue.record("Expected found, got \(m.state)"); return }

        location.fix = nil
        await m.refresh()
        #expect(m.state == .noLocation)
        #expect(m.previousResult == nil)
        #expect(m.detectedNation == nil)
    }
}

/// A time source a test can move forward, to age a result without waiting. Guarded
/// by a lock because `TimeSource` is read from wherever the model runs.
private final class AdvancingTime: TimeSource, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    init(_ now: Date) { _now = now }

    var now: Date { lock.withLock { _now } }
    var timeZone: TimeZone { TimeZone(identifier: "Europe/London") ?? .gmt }

    func advance(by seconds: TimeInterval) { lock.withLock { _now += seconds } }
}

/// A location provider whose authorization can change between calls, so a test can
/// show a person losing location access between two refreshes. `StubLocationProvider`
/// deliberately has no such setter — its authorization models what CoreLocation
/// reports at the moment of the call, fixed for the life of the double — so this
/// stays local to this test rather than widening that double for one scenario.
///
/// Every access is through a `@MainActor`-isolated member, and every call site in
/// this file is itself on the main actor (the suite is `@MainActor`), so this needs no
/// lock of its own. The doubles below that do cross actors hold their answer in a
/// `Gate`, which carries the lock.
private final class MutableAuthorizationLocationProvider: LocationProviding, @unchecked Sendable {
    @MainActor var authorization: LocationAuthorization
    @MainActor var fix: LocationFix?

    init(authorization: LocationAuthorization = .authorizedWhenInUse, fix: LocationFix?) {
        self.authorization = authorization
        self.fix = fix
    }

    @MainActor func requestWhenInUseAuthorization() async -> LocationAuthorization { authorization }
    @MainActor func currentFix(timeout: Duration) async -> LocationFix? { fix }
}

/// Answers the first call with one area, then another for every call after —
/// so a test can show a nation detected on one refresh going stale on the next.
/// No lock: see `MutableAuthorizationLocationProvider` above.
private final class TogglingAreaNamer: AreaNaming, @unchecked Sendable {
    @MainActor private var callCount = 0
    private let first: GeocodedArea?
    private let rest: GeocodedArea?

    init(first: GeocodedArea?, rest: GeocodedArea?) {
        self.first = first
        self.rest = rest
    }

    @MainActor
    func area(at coordinate: Coordinate) async -> GeocodedArea? {
        callCount += 1
        return callCount == 1 ? first : rest
    }
}

/// A police-station search that never answers until its `reply` is opened. Proves a
/// stalled search times out to a visible failure rather than leaving the busy guard
/// locked with no way forward, and that opening it lets a retry succeed.
private final class HangingPlaceSearch: PlaceSearching, @unchecked Sendable {
    let reply = Gate<PlaceSearchOutcome>()
    @MainActor private(set) var requestedRadii: [Double] = []
    /// Answered straight away to the first call only, so a test can reach a result
    /// before the search that replaces it hangs.
    @MainActor private var firstAnswer: PlaceSearchOutcome?

    init(answeringFirstWith firstAnswer: PlaceSearchOutcome? = nil) {
        self.firstAnswer = firstAnswer
    }

    @MainActor
    func policeStations(near centre: Coordinate, radiusMetres: Double) async -> PlaceSearchOutcome {
        requestedRadii.append(radiusMetres)
        if let answer = firstAnswer {
            firstAnswer = nil
            return answer
        }
        return await reply.wait()
    }
}

/// A route finder that never answers until its `reply` is opened. Proves a stalled
/// route lookup times out without hiding the station it was for.
private struct HangingRouteFinder: RouteFinding {
    let reply = Gate<RouteOutcome>()

    @MainActor
    func walkingRoute(from origin: Coordinate, to place: NearbyPlace) async -> RouteOutcome {
        await reply.wait()
    }
}

/// An area namer that never answers until its `reply` is opened. Proves a stalled
/// nation lookup times out to `nil` rather than blocking the search it must never gate.
private struct HangingAreaNamer: AreaNaming {
    let reply = Gate<GeocodedArea?>()

    @MainActor
    func area(at coordinate: Coordinate) async -> GeocodedArea? {
        await reply.wait()
    }
}

/// Hangs on its first call until `firstReply` is opened; every call after that answers
/// immediately with `subsequent`. Models a nation lookup from one refresh finishing
/// only after a later refresh has already started and finished its own — the
/// scenario that a stale answer must never be allowed to overwrite.
private final class SequencedAreaNamer: AreaNaming, @unchecked Sendable {
    let firstReply = Gate<GeocodedArea?>()
    private let subsequent: GeocodedArea?
    @MainActor private var callCount = 0

    init(subsequent: GeocodedArea?) {
        self.subsequent = subsequent
    }

    @MainActor
    func area(at coordinate: Coordinate) async -> GeocodedArea? {
        callCount += 1
        guard callCount == 1 else { return subsequent }
        return await firstReply.wait()
    }
}
