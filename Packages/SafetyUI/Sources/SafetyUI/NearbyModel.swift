import Foundation
import Observation
import SafetyContent
import SafetyDomain
import SafetyServices

/// The Nearby tab: where the person is, the nearest police stations, and which UK
/// nation's refuge routes apply.
///
/// Every location and search outcome is its own state, so the screen can always say
/// what happened and what to do next. There is no fallback position: without a real
/// fix there is no search (the 2023 build routed everyone from Trafalgar Square).
@MainActor
@Observable
public final class NearbyModel {

    public struct Found: Equatable, Sendable {
        public let origin: Coordinate
        /// When `origin` was read, by `Services.time`. Every distance and the nation
        /// are measured from it, so this is how old the whole result is.
        public let fixedAt: Date
        /// Nearest first, at most `maximumStations`.
        public let stations: [NearbyPlace]
        /// A walking route to `stations[0]`, or `nil` if one could not be planned.
        public let route: WalkingRoute?

        /// Whether this result is too old to stand for where the person is at `now`:
        /// at or past `resultMaximumAge`, or timed after `now` — the clock has moved
        /// back, so its age cannot be told, and it is not trusted.
        public func isStale(at now: Date) -> Bool {
            let age = now.timeIntervalSince(fixedAt)
            return age < 0 || age >= NearbyModel.resultMaximumAge
        }
    }

    public enum State: Equatable, Sendable {
        case idle
        case needsPermission
        case locationOff
        case locationRestricted
        /// Precise Location is off. A reading within about 5 km cannot say which
        /// station is nearest, so it is not used (US-5).
        case locationApproximate
        case locating
        case noLocation
        case searching
        case found(Found)
        case noneFound(searchedMetres: Double)
        /// The search could not run, or timed out — usually no connection.
        case searchFailed
    }

    /// Widened in steps: a town centre usually has a station within 2 km; rural areas
    /// may need up to `widestRadius`.
    public static let widestRadius: Double = 25_000
    public static let searchRadii: [Double] = [2_000, 8_000, widestRadius]
    public static let maximumStations = 5

    /// How long a found result stands for where the person is. Past it, the tab
    /// appearing or the app becoming active searches again, so stations, distances
    /// and the nation from another place, or from hours ago, are never shown as
    /// current. Long enough that switching tabs does not search every time; the alert
    /// path's `LocationFix.maximumAge` is the same idea for a single reading.
    nonisolated public static let resultMaximumAge: TimeInterval = 5 * 60

    /// None of `PlaceSearching`, `RouteFinding` or `AreaNaming` promise to return
    /// (unlike `MessageComposing`): their Task 9 implementations are plain network
    /// calls with no timeout of their own. Every await on them is bounded by
    /// `firstResult(within:_:)`, the same helper the location fix uses, so a stalled
    /// call can never leave the busy guard locked with no way forward.
    public static let defaultNationLookupTimeout: Duration = .seconds(5)
    public static let defaultSearchStepTimeout: Duration = .seconds(10)
    public static let defaultRouteTimeout: Duration = .seconds(10)

    public private(set) var state: State = .idle
    /// The UK nation the person is in, if it could be told for certain. `nil` means
    /// the refuge list asks rather than guessing — including after a refresh whose
    /// lookup failed, found no nation, timed out, or never ran because location was
    /// unavailable, so a nation from an earlier refresh is never shown as chosen from
    /// a location that no longer holds.
    public private(set) var detectedNation: Nation?
    public var directionsFailed = false

    /// The result a running refresh is replacing, kept so the screen can go on
    /// showing it — marked as updating — instead of blanking. Set only while
    /// `isBusy`; cleared the moment the refresh reaches any other state, so a failed
    /// refresh shows its failure and never leaves the old result looking current.
    public private(set) var previousResult: Found?

    public var isBusy: Bool { state == .locating || state == .searching }

    /// Whether the tab appearing, or the app becoming active, should start a
    /// refresh: never while one is running; for a found result only once it is stale
    /// (`resultMaximumAge`); and always otherwise, so a permission fixed in Settings,
    /// a signal that came back or a first visit is picked up without a tap.
    public var shouldRefreshOnReturn: Bool {
        switch state {
        case .locating, .searching: false
        case let .found(found): found.isStale(at: services.time.now)
        case .idle, .needsPermission, .locationOff, .locationRestricted, .locationApproximate,
             .noLocation, .noneFound, .searchFailed: true
        }
    }

    private let services: Services
    private let locationTimeout: Duration
    private let nationLookupTimeout: Duration
    private let searchStepTimeout: Duration
    private let routeTimeout: Duration

    /// Counts each `refresh()` call. Because `state` reaches a terminal value (and
    /// so `isBusy` goes false) before the nation lookup's own tail is awaited, a new
    /// refresh can start and finish while an old one is still only waiting on that
    /// lookup. Captured per call as `myGeneration`, so a late-arriving nation from an
    /// old refresh can be told apart from the current one and never overwrite it —
    /// the same stale-nation defect this model exists to prevent, reached by a path
    /// this restructuring opened up rather than by the location/lookup paths above.
    private var refreshGeneration = 0

    public init(
        services: Services,
        locationTimeout: Duration = .seconds(10),
        nationLookupTimeout: Duration = defaultNationLookupTimeout,
        searchStepTimeout: Duration = defaultSearchStepTimeout,
        routeTimeout: Duration = defaultRouteTimeout
    ) {
        self.services = services
        self.locationTimeout = locationTimeout
        self.nationLookupTimeout = nationLookupTimeout
        self.searchStepTimeout = searchStepTimeout
        self.routeTimeout = routeTimeout
    }

    /// The tab appeared or the app became active: refresh if `shouldRefreshOnReturn`.
    public func refreshIfNeeded() async {
        guard shouldRefreshOnReturn else { return }
        await refresh()
    }

    public func refresh() async {
        guard !isBusy else { return }
        refreshGeneration += 1
        let myGeneration = refreshGeneration

        switch services.location.authorization {
        case .notDetermined:
            detectedNation = nil
            return finish(.needsPermission)
        case .denied:
            detectedNation = nil
            return finish(.locationOff)
        case .restricted:
            detectedNation = nil
            return finish(.locationRestricted)
        case .authorizedReducedAccuracy:
            detectedNation = nil
            return finish(.locationApproximate)
        case .authorizedWhenInUse: break
        }

        // The old result stays on screen, marked as updating, until this refresh
        // lands or fails. Its nation does not: it came from the reading being
        // replaced, so the refuge list asks rather than label it "from your location".
        if case let .found(found) = state { previousResult = found }
        detectedNation = nil
        state = .locating
        let location = services.location
        let fixTimeout = locationTimeout
        guard let fix = await firstResult(within: fixTimeout, { await location.currentFix(timeout: fixTimeout) }) else {
            detectedNation = nil
            return finish(.noLocation)
        }
        let origin = fix.coordinate
        let fixedAt = services.time.now

        // Moves past "locating" the moment the fix arrives. The nation lookup never
        // gates the station search — it runs alongside it — and it is only folded
        // into `detectedNation` after the search has already produced its own state,
        // so a slow lookup never delays the stations being shown.
        state = .searching
        let areas = services.areas
        let places = services.places
        let routes = services.routes
        let nationTimeout = nationLookupTimeout
        let stepTimeout = searchStepTimeout
        let routeTimeoutValue = routeTimeout
        async let areaLookup = firstResult(within: nationTimeout) { await areas.area(at: origin) }

        for radius in Self.searchRadii {
            switch await firstResult(within: stepTimeout, { await places.policeStations(near: origin, radiusMetres: radius) }) {
            case nil, .failed:
                // A timed-out search is reported exactly like one that could not run:
                // a visible failure with a retry, never "nothing nearby".
                finish(.searchFailed)
                applyNation(await areaLookup, generation: myGeneration)
                return
            case .noneFound:
                continue
            case let .found(found):
                let nearest = Array(found.nearestFirst(from: origin).prefix(Self.maximumStations))
                guard let first = nearest.first else { continue }
                let route: WalkingRoute? = switch await firstResult(within: routeTimeoutValue, { await routes.walkingRoute(from: origin, to: first) }) {
                case .found(let route)?: route
                // A missing or timed-out route never hides the station: it is shown
                // without one.
                case .failed?, nil: nil
                }
                finish(.found(Found(origin: origin, fixedAt: fixedAt, stations: nearest, route: route)))
                applyNation(await areaLookup, generation: myGeneration)
                return
            }
        }
        finish(.noneFound(searchedMetres: Self.widestRadius))
        applyNation(await areaLookup, generation: myGeneration)
    }

    /// The only place the location prompt is shown from: an explicit button.
    public func allowLocation() async {
        _ = await services.location.requestWhenInUseAuthorization()
        await refresh()
    }

    public func openDirections(to place: NearbyPlace) async {
        // Self-correcting: a later success clears a previous failure, so the flag
        // never outlives the attempt that set it.
        directionsFailed = await services.maps.openWalkingDirections(to: place) == false
    }

    /// Every state a refresh ends in goes through here, so the result it replaced
    /// never outlives it.
    private func finish(_ newState: State) {
        previousResult = nil
        state = newState
    }

    /// Resolves an awaited area lookup to `detectedNation`, unless a newer `refresh()`
    /// has already started — see `refreshGeneration`. `nil` when the lookup timed
    /// out, found nothing, or the area is not a UK nation: `Nation(area:)` already
    /// returns `nil` for the last case, so a timed-out lookup is simply handled the
    /// same way — the refuge list asks rather than guessing.
    private func applyNation(_ lookup: GeocodedArea?, generation myGeneration: Int) {
        guard myGeneration == refreshGeneration else { return }
        detectedNation = lookup.flatMap(Nation.init(area:))
    }
}
