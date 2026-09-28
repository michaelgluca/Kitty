import CoreLocation
import MapKit
import os
import SafetyDomain
import SafetyServices

/// Never logs a coordinate or a place. Only that something failed.
nonisolated private let nearbyLog = Logger(subsystem: "uk.co.example.safety", category: "nearby")

private extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var clLocation: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

private extension MKMapItem {
    var nearbyPlace: NearbyPlace {
        let c = location.coordinate
        // Falls back to the coordinate when MapKit gives no identifier. The name is
        // folded in too: two distinct co-located POIs (for example inside the same
        // police building) would otherwise collide on the same "lat,lon" id.
        let fallback = "\(name ?? "")@\(c.latitude),\(c.longitude)"
        return NearbyPlace(
            id: identifier?.rawValue ?? fallback,
            name: name,
            coordinate: Coordinate(latitude: c.latitude, longitude: c.longitude),
            phone: phoneNumber
        )
    }
}

/// Police stations from Apple Maps.
///
/// Every step — near or wide — searches by name as well as category: Apple's
/// `.police` points-of-interest category alone is broader than "police station" and
/// also covers things like a museum inside a police building or a heritage police
/// telephone box (both were returned by a live search near Waterloo). There
/// is no way to combine a natural-language query with
/// `MKLocalPointsOfInterestRequest` (it has no query property), so every radius uses
/// `MKLocalSearch.Request` instead, and every result is also checked against
/// `readsAsPoliceStation(name:)` before being returned — belt and braces alongside
/// MapKit's own category filter. Results beyond the radius are dropped, so "nothing
/// within N" is true when it is said, and a radius that filters down to nothing
/// reports `.noneFound` rather than an unfiltered fallback, so `NearbyModel` widens
/// the search exactly as it does for a genuinely empty area.
struct MapKitPlaceSearch: PlaceSearching {

    func policeStations(near centre: Coordinate, radiusMetres: Double) async -> PlaceSearchOutcome {
        let request = MKLocalSearch.Request()
        // A search term for Apple Maps, never shown to anyone. The category filter
        // and result type below narrow it to points of interest; the name filter
        // applied to the response is what actually keeps this to police stations.
        request.naturalLanguageQuery = "police station"
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.police])
        request.region = MKCoordinateRegion(
            center: centre.clCoordinate,
            latitudinalMeters: radiusMetres * 2,
            longitudinalMeters: radiusMetres * 2
        )
        let search = MKLocalSearch(request: request)

        do {
            let response = try await withTaskCancellationHandler {
                try await search.start()
            } onCancel: {
                search.cancel()
            }
            let places = response.mapItems
                .filter { $0.pointOfInterestCategory == .police }
                .map(\.nearbyPlace)
                .filter { readsAsPoliceStation(name: $0.name) }
                .filter { Distance.metres(from: centre, to: $0.coordinate) <= radiusMetres }
            return places.isEmpty ? .noneFound : .found(places)
        } catch let error as MKError where error.code == .placemarkNotFound {
            return .noneFound
        } catch {
            nearbyLog.error("Police-station search failed")
            return .failed
        }
    }
}

struct MapKitRouteFinder: RouteFinding {

    func walkingRoute(from origin: Coordinate, to place: NearbyPlace) async -> RouteOutcome {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: origin.clLocation, address: nil)
        request.destination = MKMapItem(location: place.coordinate.clLocation, address: nil)
        request.transportType = .walking
        let directions = MKDirections(request: request)
        do {
            let response = try await withTaskCancellationHandler {
                try await directions.calculate()
            } onCancel: {
                directions.cancel()
            }
            guard let route = response.routes.first else { return .failed }
            let polyline = route.polyline
            var points = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
            polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
            return .found(WalkingRoute(
                distanceMetres: route.distance,
                expectedSeconds: route.expectedTravelTime,
                path: points.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
            ))
        } catch {
            nearbyLog.error("Walking route failed")
            return .failed
        }
    }
}

/// Turn-by-turn is Apple Maps' job (ADR-0013).
struct AppleMapsOpener: MapsOpening {

    func openWalkingDirections(to place: NearbyPlace) async -> Bool {
        let item = MKMapItem(location: place.coordinate.clLocation, address: nil)
        item.name = place.name
        return item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// Which UK nation the person is in, so the refuge list can start in the right place.
/// Names are requested in British English so the nation names match.
struct MapKitAreaNamer: AreaNaming {

    func area(at coordinate: Coordinate) async -> GeocodedArea? {
        guard let request = MKReverseGeocodingRequest(location: coordinate.clLocation) else { return nil }
        request.preferredLocale = Locale(identifier: "en_GB")
        do {
            guard let item = try await request.mapItems.first else { return nil }
            let representations = item.addressRepresentations
            // `regionName` is the country ("United Kingdom"), not the nation, and must
            // not be used here — a live probe confirmed this. `cityWithContext` (e.g.
            // "Glasgow, Scotland") and the full address are what actually carry the
            // nation, as the last comma-separated part.
            let names = [representations?.cityWithContext, item.address?.fullAddress].compactMap { $0 }
            return GeocodedArea(countryCode: representations?.region?.identifier, names: names)
        } catch {
            // The refuge list then asks the person where they are.
            nearbyLog.error("Reverse geocoding failed")
            return nil
        }
    }
}
