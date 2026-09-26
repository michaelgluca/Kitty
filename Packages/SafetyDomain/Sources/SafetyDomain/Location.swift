import Foundation

/// A WGS-84 coordinate.
///
/// Deliberately not `CLLocationCoordinate2D`: this type crosses to watchOS and, in
/// concept, to the Kotlin port. CoreLocation is converted at the service boundary.
public struct Coordinate: Hashable, Sendable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isPlausible: Bool {
        guard latitude >= -90, latitude <= 90, longitude >= -180, longitude <= 180 else { return false }
        // data.police.uk emits (0, 0) for withheld points, which otherwise plots in
        // the Gulf of Guinea. Treat null island as missing data everywhere.
        return !(latitude == 0 && longitude == 0)
    }

    /// Rounded to roughly a kilometre.
    ///
    /// Used before any coordinate leaves the device toward a third-party service.
    /// `data.police.uk` searches a one-mile radius regardless, so precision buys
    /// nothing there and costs privacy. See ADR-0011.
    public func coarsened() -> Coordinate {
        Coordinate(
            latitude: (latitude * 100).rounded() / 100,
            longitude: (longitude * 100).rounded() / 100
        )
    }
}

/// A location reading, with enough context to decide whether it is worth using.
public struct LocationFix: Hashable, Sendable {
    public let coordinate: Coordinate
    /// Horizontal accuracy in metres. Negative means invalid.
    public let horizontalAccuracy: Double
    public let timestamp: Date

    public init(coordinate: Coordinate, horizontalAccuracy: Double, timestamp: Date) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }

    /// Reduced accuracy — the user's Precise Location switch off — yields readings
    /// on the order of 5 km. That cannot support "here is where I am", so it is
    /// surfaced honestly as unusable rather than sent as though it were a location.
    public static let usableAccuracyThreshold: Double = 1_000

    public var isUsable: Bool {
        coordinate.isPlausible && horizontalAccuracy >= 0 && horizontalAccuracy <= Self.usableAccuracyThreshold
    }
}
