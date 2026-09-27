import Foundation
import SafetyDomain

/// The set of capabilities the app is built from.
///
/// A struct of protocol existentials rather than a container type, so the wiring is
/// visible at a glance and a test or a preview can replace exactly one thing. Lives
/// here rather than in the app target so `SafetyUI` can read it from the environment
/// without depending on the app. See ADR-0003.
public struct Services: Sendable {
    public var location: any LocationProviding
    public var messages: any MessageComposing
    public var dialler: any Dialling
    public var texter: any TextOpening
    public var picker: any ContactPicking
    public var settings: any SettingsOpening
    public var contacts: any TrustedContactStoring
    public var battery: any BatteryReading
    public var time: any TimeSource
    public var places: any PlaceSearching
    public var routes: any RouteFinding
    public var maps: any MapsOpening
    public var areas: any AreaNaming
    public var nations: any NationStoring

    public init(
        location: any LocationProviding,
        messages: any MessageComposing,
        dialler: any Dialling,
        texter: any TextOpening,
        picker: any ContactPicking,
        settings: any SettingsOpening,
        contacts: any TrustedContactStoring,
        battery: any BatteryReading,
        time: any TimeSource,
        places: any PlaceSearching,
        routes: any RouteFinding,
        maps: any MapsOpening,
        areas: any AreaNaming,
        nations: any NationStoring
    ) {
        self.location = location
        self.messages = messages
        self.dialler = dialler
        self.texter = texter
        self.picker = picker
        self.settings = settings
        self.contacts = contacts
        self.battery = battery
        self.time = time
        self.places = places
        self.routes = routes
        self.maps = maps
        self.areas = areas
        self.nations = nations
    }

    /// Everything reports its own unavailability.
    ///
    /// The default for previews and for any environment that forgot to inject. It is
    /// deliberately not a set of no-ops that silently succeed: a stub returning
    /// success would let a broken flow look healthy, which is exactly how the 2023
    /// build shipped a Face ID gate that never locked.
    public static var unavailable: Services {
        Services(
            location: UnavailableLocationProvider(),
            messages: UnavailableMessageComposer(),
            dialler: UnavailableDialler(),
            texter: UnavailableTextOpener(),
            picker: UnavailableContactPicker(),
            settings: UnavailableSettingsOpener(),
            contacts: EphemeralContactStore(),
            battery: UnknownBattery(),
            time: SystemTimeSource(),
            places: UnavailablePlaceSearch(),
            routes: UnavailableRouteFinder(),
            maps: UnavailableMapsOpener(),
            areas: UnavailableAreaNamer(),
            nations: UnavailableNationStore()
        )
    }
}

public struct UnavailableLocationProvider: LocationProviding {
    public init() {}
    @MainActor public var authorization: LocationAuthorization { .notDetermined }
    @MainActor public func requestWhenInUseAuthorization() async -> LocationAuthorization { .notDetermined }
    @MainActor public func currentFix(timeout: Duration) async -> LocationFix? { nil }
}

public struct UnavailableMessageComposer: MessageComposing {
    public init() {}
    @MainActor public var canSendText: Bool { false }
    @MainActor
    public func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome { .unavailable }
}

public struct UnavailableContactPicker: ContactPicking {
    public init() {}
    @MainActor public func pickContact() async -> ContactPickOutcome { .unavailable }
}

public struct UnavailableSettingsOpener: SettingsOpening {
    public init() {}
    @MainActor public func openAppSettings() async -> Bool { false }
}

public struct UnavailableDialler: Dialling {
    public init() {}
    @MainActor
    public func dial(_ number: PhoneNumber) async -> Bool { false }
}

public struct UnavailableTextOpener: TextOpening {
    public init() {}
    @MainActor
    public func openText(to number: PhoneNumber) async -> Bool { false }
}

public struct UnknownBattery: BatteryReading {
    public init() {}
    public var fraction: Double? { nil }
}

public struct UnavailablePlaceSearch: PlaceSearching {
    public init() {}
    @MainActor public func policeStations(near centre: Coordinate, radiusMetres: Double) async -> PlaceSearchOutcome { .failed }
}

public struct UnavailableRouteFinder: RouteFinding {
    public init() {}
    @MainActor public func walkingRoute(from origin: Coordinate, to place: NearbyPlace) async -> RouteOutcome { .failed }
}

public struct UnavailableMapsOpener: MapsOpening {
    public init() {}
    @MainActor public func openWalkingDirections(to place: NearbyPlace) async -> Bool { false }
}

public struct UnavailableAreaNamer: AreaNaming {
    public init() {}
    @MainActor public func area(at coordinate: Coordinate) async -> GeocodedArea? { nil }
}

/// Reports that nothing can be read or saved, so a screen given no real store says so
/// rather than quietly forgetting the person's choice.
public struct UnavailableNationStore: NationStoring {
    public init() {}
    public func load() throws -> String? { throw NationStoreFailure.unavailable }
    public func save(_ nationID: String?) throws { throw NationStoreFailure.unavailable }
}

/// Holds nothing across launches. Used only as a safe default.
public final class EphemeralContactStore: TrustedContactStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var contacts: [TrustedContact] = []
    public init() {}
    public func load() throws -> [TrustedContact] { lock.withLock { contacts } }
    public func save(_ contacts: [TrustedContact]) throws { lock.withLock { self.contacts = contacts } }
}
