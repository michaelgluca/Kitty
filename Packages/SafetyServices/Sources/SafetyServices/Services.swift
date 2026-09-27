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
    public var contacts: any TrustedContactStoring
    public var battery: any BatteryReading
    public var time: any TimeSource

    public init(
        location: any LocationProviding,
        messages: any MessageComposing,
        dialler: any Dialling,
        texter: any TextOpening,
        contacts: any TrustedContactStoring,
        battery: any BatteryReading,
        time: any TimeSource
    ) {
        self.location = location
        self.messages = messages
        self.dialler = dialler
        self.texter = texter
        self.contacts = contacts
        self.battery = battery
        self.time = time
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
            contacts: EphemeralContactStore(),
            battery: UnknownBattery(),
            time: SystemTimeSource()
        )
    }
}

public struct UnavailableLocationProvider: LocationProviding {
    public init() {}
    public var authorization: LocationAuthorization { get async { .notDetermined } }
    public func requestWhenInUseAuthorization() async -> LocationAuthorization { .notDetermined }
    public func currentFix(timeout: Duration) async -> LocationFix? { nil }
}

public struct UnavailableMessageComposer: MessageComposing {
    public init() {}
    public var canSendText: Bool { false }
    @MainActor
    public func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome { .unavailable }
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

/// Holds nothing across launches. Used only as a safe default.
public final class EphemeralContactStore: TrustedContactStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var contacts: [TrustedContact] = []
    public init() {}
    public func load() throws -> [TrustedContact] { lock.withLock { contacts } }
    public func save(_ contacts: [TrustedContact]) throws { lock.withLock { self.contacts = contacts } }
}
