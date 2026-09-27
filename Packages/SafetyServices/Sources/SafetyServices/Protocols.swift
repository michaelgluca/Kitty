import Foundation
import SafetyDomain

// MARK: - Location

public enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    /// Precise Location is off. Readings are around 5 km, which cannot support
    /// "here is where I am", so this is surfaced rather than quietly used.
    case authorizedReducedAccuracy
}

public protocol LocationProviding: Sendable {
    /// Read synchronously: CoreLocation reports it without a round trip.
    @MainActor var authorization: LocationAuthorization { get }

    /// Shows the system prompt only when the answer is not yet known; otherwise
    /// returns the current state straight away.
    @MainActor func requestWhenInUseAuthorization() async -> LocationAuthorization

    /// A single fix, or `nil` if none arrives within `timeout`.
    ///
    /// Returning `nil` rather than throwing is deliberate: the caller must carry on
    /// and send the alert without a location. Raising an alert is never blocked on
    /// location, and never fails because of it. Must never show a permission prompt:
    /// it is called from the alert path.
    @MainActor func currentFix(timeout: Duration) async -> LocationFix?
}

// MARK: - Messaging

public enum MessageOutcome: Sendable, Equatable {
    case sent
    case cancelled
    case failed
    /// The device cannot send texts at all — no SIM, or a restriction. The caller
    /// must offer another route rather than leaving the user with a dead button.
    case unavailable
}

public protocol MessageComposing: Sendable {
    @MainActor var canSendText: Bool { get }

    /// Presents the system composer, pre-filled. iOS never sends without the user
    /// tapping Send, and never will — see ADR-0002. The returned outcome says what
    /// the user actually did, which is what lets the UI avoid claiming success.
    ///
    /// Must always return. The alert stays busy for as long as this call is in
    /// flight, so an implementation that never returns would hang the alert with
    /// it. If the composer sheet itself cannot be presented, report `.failed`
    /// rather than never completing.
    @MainActor
    func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome
}

// MARK: - Calling

public protocol Dialling: Sendable {
    /// Opens the system dialler. Always `tel:`, never `telprompt:`, so the system
    /// confirmation is shown. Returns whether the dialler actually opened.
    @MainActor
    func dial(_ number: PhoneNumber) async -> Bool
}

public protocol TextOpening: Sendable {
    /// Opens Messages to a number, with nothing pre-filled. Returns whether Messages
    /// actually opened.
    ///
    /// A separate capability from `Dialling`, deliberately. A text-only destination
    /// such as British Transport Police's 61016 must never reach a call path.
    @MainActor
    func openText(to number: PhoneNumber) async -> Bool
}

// MARK: - Storage

public protocol TrustedContactStoring: Sendable {
    func load() throws -> [TrustedContact]
    func save(_ contacts: [TrustedContact]) throws
}

// MARK: - Choosing contacts

/// What the system contact picker handed back: one person, and the one number they
/// chose for them.
public struct PickedContact: Sendable, Equatable {
    /// May be empty — a contact saved as a number only. The domain rules then show
    /// the number instead of a blank name.
    public let displayName: String
    public let phoneNumber: String

    public init(displayName: String, phoneNumber: String) {
        self.displayName = displayName
        self.phoneNumber = phoneNumber
    }
}

public enum ContactPickOutcome: Sendable, Equatable {
    case picked(PickedContact)
    case cancelled
    /// The picker could not be shown. Reported, so the screen can say so.
    case unavailable
}

public protocol ContactPicking: Sendable {
    /// Presents the out-of-process system picker. It needs no Contacts permission:
    /// the app only ever sees the one contact and number the person chooses.
    @MainActor func pickContact() async -> ContactPickOutcome
}

// MARK: - Settings

public protocol SettingsOpening: Sendable {
    /// Opens this app's page in the Settings app. Returns whether it opened.
    @MainActor func openAppSettings() async -> Bool
}

// MARK: - Device

public protocol BatteryReading: Sendable {
    /// 0…1, or `nil` when unknown (the simulator reports no level).
    var fraction: Double? { get }
}

public protocol TimeSource: Sendable {
    var now: Date { get }
    var timeZone: TimeZone { get }
}

public struct SystemTimeSource: TimeSource {
    public init() {}
    public var now: Date { Date() }
    public var timeZone: TimeZone { TimeZone.autoupdatingCurrent }
}

// MARK: - Nearby

public enum PlaceSearchOutcome: Sendable, Equatable {
    case found([NearbyPlace])
    /// The search ran and there is nothing in range.
    case noneFound
    /// The search could not run — usually no connection. Reported, never shown as
    /// "nothing nearby", which would be a different and false statement.
    case failed
}

public protocol PlaceSearching: Sendable {
    /// Police stations within `radiusMetres` of `centre`, in whatever order the map
    /// service returns them. The caller orders them.
    @MainActor func policeStations(near centre: Coordinate, radiusMetres: Double) async -> PlaceSearchOutcome
}

public enum RouteOutcome: Sendable, Equatable {
    case found(WalkingRoute)
    case failed
}

public protocol RouteFinding: Sendable {
    @MainActor func walkingRoute(from origin: Coordinate, to place: NearbyPlace) async -> RouteOutcome
}

public protocol MapsOpening: Sendable {
    /// Opens Apple Maps with walking directions to the place. Returns whether it opened.
    @MainActor func openWalkingDirections(to place: NearbyPlace) async -> Bool
}

public protocol AreaNaming: Sendable {
    /// Where a coordinate is, or `nil` if that cannot be found (for example, offline).
    @MainActor func area(at coordinate: Coordinate) async -> GeocodedArea?
}
