#if DEBUG
import Foundation
import SafetyDomain
import SafetyServices

/// Launch switches for the UI tests. Compiled only into debug builds, so none of
/// this exists in anything shipped to the App Store.
///
/// - `-kitty.uiTest`: use a separate Keychain item for trusted contacts, so running
///   the tests never touches a developer's real list.
/// - `-kitty.resetContacts`: start with no trusted contacts.
/// - `-kitty.seedContacts`: start with two contacts on Ofcom drama numbers.
/// - `-kitty.withoutContent`: behave as if the bundled content pack failed to load,
///   so the screens' missing-content states can be tested. Honoured only together
///   with `-kitty.uiTest`.
/// - `-kitty.stubNearby`: a fixed world for the Nearby UI tests, so they need no
///   real location, network or Apple Maps data. Honoured only together with
///   `-kitty.uiTest`.
enum UITestSupport {

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isActive: Bool { arguments.contains("-kitty.uiTest") }

    static var withoutContent: Bool { isActive && arguments.contains("-kitty.withoutContent") }

    static var stubsNearby: Bool { isActive && arguments.contains("-kitty.stubNearby") }

    static func prepare(_ store: any TrustedContactStoring) {
        guard isActive else { return }
        do {
            if arguments.contains("-kitty.resetContacts") {
                try store.save([])
            }
            if arguments.contains("-kitty.seedContacts") {
                try store.save([
                    TrustedContact(displayName: "Alice", phoneNumber: .drama(1)),
                    TrustedContact(displayName: "Bob", phoneNumber: .drama(2)),
                ])
            }
        } catch {
            // A UI test that silently ran against the wrong data would prove nothing.
            fatalError("UI test setup could not prepare trusted contacts: \(error)")
        }
    }

    /// A fixed world for the Nearby UI tests, so they need no real location, network
    /// or Apple Maps data. Debug builds only.
    static func stubNearby(_ services: inout Services) {
        let here = Coordinate(latitude: 51.5033, longitude: -0.1196)
        let station = NearbyPlace(
            id: "test-station",
            name: "Test Police Station",
            coordinate: Coordinate(latitude: 51.5069, longitude: -0.1196),
            phone: nil
        )
        services.location = FixedLocation(coordinate: here)
        services.places = FixedPlaces(result: .found([station]))
        services.routes = FixedRoute(result: .found(WalkingRoute(distanceMetres: 450, expectedSeconds: 360, path: [here, station.coordinate])))
        services.areas = FixedArea(result: GeocodedArea(countryCode: "GB", names: ["England"]))
    }
}

private struct FixedLocation: LocationProviding {
    let coordinate: Coordinate
    var authorization: LocationAuthorization { .authorizedWhenInUse }
    func requestWhenInUseAuthorization() async -> LocationAuthorization { .authorizedWhenInUse }
    func currentFix(timeout: Duration) async -> LocationFix? {
        LocationFix(coordinate: coordinate, horizontalAccuracy: 10, timestamp: Date())
    }
}

private struct FixedPlaces: PlaceSearching {
    let result: PlaceSearchOutcome
    func policeStations(near centre: Coordinate, radiusMetres: Double) async -> PlaceSearchOutcome { result }
}

private struct FixedRoute: RouteFinding {
    let result: RouteOutcome
    func walkingRoute(from origin: Coordinate, to place: NearbyPlace) async -> RouteOutcome { result }
}

private struct FixedArea: AreaNaming {
    let result: GeocodedArea?
    func area(at coordinate: Coordinate) async -> GeocodedArea? { result }
}
#endif
