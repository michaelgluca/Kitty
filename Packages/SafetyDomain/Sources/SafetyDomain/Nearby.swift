import Foundation

/// A place found near the person — for now, a police station.
///
/// Deliberately not `MKMapItem`: this type stays platform-neutral (ADR-0003). MapKit
/// is converted at the service boundary.
public struct NearbyPlace: Identifiable, Hashable, Sendable {
    public let id: String
    /// `nil` when the map data has no name. The screen shows a generic label instead,
    /// never an invented one.
    public let name: String?
    public let coordinate: Coordinate
    public let phone: String?

    public init(id: String, name: String?, coordinate: Coordinate, phone: String?) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.phone = phone
    }
}

/// A walking route, reduced to what the screen needs: how far, how long, and the line
/// to draw. Turn-by-turn directions are Apple Maps' job (ADR-0013).
public struct WalkingRoute: Hashable, Sendable {
    public let distanceMetres: Double
    public let expectedSeconds: Double
    public let path: [Coordinate]

    public init(distanceMetres: Double, expectedSeconds: Double, path: [Coordinate]) {
        self.distanceMetres = distanceMetres
        self.expectedSeconds = expectedSeconds
        self.path = path
    }
}

/// Where a coordinate is, as the map service names it.
public struct GeocodedArea: Hashable, Sendable {
    /// ISO 3166-1 alpha-2, such as "GB". `nil` when unknown.
    public let countryCode: String?
    /// Names for the area, most specific first — a locality with context (e.g. "Glasgow, Scotland"),
    /// then the full address (e.g. "1 Main St, Glasgow, G2, Scotland"). The nation is the last
    /// comma-separated part of these strings. MapKit's `regionName` is the country ("United Kingdom"),
    /// not the nation, and must not be placed here.
    public let names: [String]

    public init(countryCode: String?, names: [String]) {
        self.countryCode = countryCode
        self.names = names
    }
}

public enum Distance {

    private static let earthRadiusMetres = 6_371_000.0

    /// Great-circle distance in metres (haversine). Well within 1% at the distances
    /// this app deals in, which is all a "nearest" ordering needs.
    public static func metres(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMetres * asin(min(1, sqrt(h)))
    }
}

public extension Array where Element == NearbyPlace {

    /// Nearest first. Places with implausible coordinates are dropped: map data can
    /// carry (0, 0), which would otherwise be listed as a real place.
    func nearestFirst(from origin: Coordinate) -> [NearbyPlace] {
        filter { $0.coordinate.isPlausible }
            .map { (place: $0, metres: Distance.metres(from: origin, to: $0.coordinate)) }
            .sorted { $0.metres < $1.metres }
            .map(\.place)
    }
}

/// Whether `name` reads as an actual police station — a front counter someone in
/// danger could walk into — rather than merely something MapKit's `.police`
/// points-of-interest category also covers, such as a museum inside a police
/// building or a heritage police telephone box. Apple's category is broader than
/// "police station", so a map-service result must pass this before it is shown as
/// one. Pure and platform-neutral, so it is testable without a device and reusable
/// by the later Kotlin port.
///
/// The reject list is checked first, because the places it catches — "The Old
/// Police Station" pub, a "Police Station Museum", a telephone box — also read as a
/// station by name. The accept rules cover all four nations: English and Scottish
/// wording, Welsh ("Gorsaf Heddlu", or "Gorsaf yr Heddlu"), and the Police Service of
/// Northern Ireland. A real station that fails them is hidden, and a farther one is
/// then shown as nearest, so a missing nation's wording is a defect, not a nicety.
public func readsAsPoliceStation(name: String?) -> Bool {
    guard let name, !name.isEmpty else { return false }
    let lower = name.lowercased()
    let words = lower.split(whereSeparator: { !$0.isLetter }).map(String.init)
    // Padded with spaces so a phrase matches only whole words: "old police station"
    // must not match "Bold Police Station".
    let spaced = " " + words.joined(separator: " ") + " "

    if words.contains(where: PoliceStationName.rejectedWords.contains) { return false }
    if PoliceStationName.rejectedPhrases.contains(where: { spaced.contains(" \($0) ") }) { return false }

    if lower.contains("police office") { return true }
    if lower.contains("psni") { return true }
    if lower.contains("police service of northern ireland") { return true }
    if lower.contains("police") && lower.contains("station") { return true }
    // Welsh: "gorsaf" alone is any station (a railway station), and "heddlu" alone is
    // the force (a headquarters or a force name), so both must be present.
    if words.contains("gorsaf") && words.contains("heddlu") { return true }
    return false
}

private enum PoliceStationName {
    /// Whole words that mean the place is not a working station. "Amgueddfa" is
    /// Welsh for museum.
    static let rejectedWords: Set<String> = ["museum", "amgueddfa", "former", "closed", "telephone"]
    /// Whole-word phrases that mean the same.
    static let rejectedPhrases = ["old police station", "police box", "phone box"]
}
