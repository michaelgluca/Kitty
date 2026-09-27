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
        /// Nearest first, at most `maximumStations`.
        public let stations: [NearbyPlace]
        /// A walking route to `stations[0]`, or `nil` if one could not be planned.
        public let route: WalkingRoute?
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
        /// The search could not run — usually no connection.
        case searchFailed
    }

    /// Widened in steps: a town centre usually has a station within 2 km; rural areas
    /// may need 25.
    public static let searchRadii: [Double] = [2_000, 8_000, 25_000]
    public static let maximumStations = 5

    public private(set) var state: State = .idle
    /// The UK nation the person is in, if it could be told for certain. `nil` means
    /// the refuge list asks rather than guessing — including after a refresh that
    /// found no nation, so a nation detected on an earlier refresh is never shown
    /// stale once it no longer holds.
    public private(set) var detectedNation: Nation?
    public var directionsFailed = false

    public var isBusy: Bool { state == .locating || state == .searching }

    private let services: Services
    private let locationTimeout: Duration

    public init(services: Services, locationTimeout: Duration = .seconds(10)) {
        self.services = services
        self.locationTimeout = locationTimeout
    }

    public func refresh() async {
        guard !isBusy else { return }

        switch services.location.authorization {
        case .notDetermined:
            detectedNation = nil
            return state = .needsPermission
        case .denied:
            detectedNation = nil
            return state = .locationOff
        case .restricted:
            detectedNation = nil
            return state = .locationRestricted
        case .authorizedReducedAccuracy:
            detectedNation = nil
            return state = .locationApproximate
        case .authorizedWhenInUse: break
        }

        state = .locating
        let location = services.location
        let timeout = locationTimeout
        guard let fix = await firstResult(within: timeout, { await location.currentFix(timeout: timeout) }) else {
            detectedNation = nil
            return state = .noLocation
        }
        let origin = fix.coordinate

        if let area = await services.areas.area(at: origin) {
            detectedNation = Nation(area: area)
        } else {
            detectedNation = nil
        }

        state = .searching
        for radius in Self.searchRadii {
            switch await services.places.policeStations(near: origin, radiusMetres: radius) {
            case .failed:
                return state = .searchFailed
            case .noneFound:
                continue
            case let .found(places):
                let nearest = Array(places.nearestFirst(from: origin).prefix(Self.maximumStations))
                guard let first = nearest.first else { continue }
                let route: WalkingRoute? = switch await services.routes.walkingRoute(from: origin, to: first) {
                case let .found(route): route
                case .failed: nil
                }
                return state = .found(Found(origin: origin, stations: nearest, route: route))
            }
        }
        state = .noneFound(searchedMetres: Self.searchRadii.last ?? 0)
    }

    /// The only place the location prompt is shown from: an explicit button.
    public func allowLocation() async {
        _ = await services.location.requestWhenInUseAuthorization()
        await refresh()
    }

    public func openDirections(to place: NearbyPlace) async {
        if await services.maps.openWalkingDirections(to: place) == false {
            directionsFailed = true
        }
    }
}
