import Foundation
import SafetyDomain
import SafetyServices

/// Numbers from Ofcom's reserved drama range, which cannot reach a real subscriber.
/// Every fixture and every Test Mode path uses these, so no test can ever text or
/// call a person.
public enum SafeTestNumbers {
    public static let alice = PhoneNumber("+447700900001")!
    public static let bob = PhoneNumber("+447700900002")!

    public static var contacts: [TrustedContact] {
        [
            TrustedContact(displayName: "Alice (test)", phoneNumber: alice),
            TrustedContact(displayName: "Bob (test)", phoneNumber: bob),
        ]
    }
}

public final class StubLocationProvider: LocationProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _authorization: LocationAuthorization
    private var _fix: LocationFix?
    private var _delay: Duration

    public private(set) var fixRequestCount = 0

    public init(
        authorization: LocationAuthorization = .authorizedWhenInUse,
        fix: LocationFix? = nil,
        delay: Duration = .zero
    ) {
        self._authorization = authorization
        self._fix = fix
        self._delay = delay
    }

    public var authorization: LocationAuthorization {
        get async { lock.withLock { _authorization } }
    }

    public func requestWhenInUseAuthorization() async -> LocationAuthorization {
        lock.withLock { _authorization }
    }

    public func currentFix(timeout: Duration) async -> LocationFix? {
        lock.withLock { fixRequestCount += 1 }
        let (fix, delay) = lock.withLock { (_fix, _delay) }
        if delay > .zero {
            // Model a slow fix so callers can prove they carry on without one.
            if delay > timeout { return nil }
            try? await Task.sleep(for: delay)
        }
        return fix
    }
}

public final class SpyMessageComposer: MessageComposing, @unchecked Sendable {
    public struct Composed: Sendable, Equatable {
        public let recipients: [PhoneNumber]
        public let body: String
    }

    private let lock = NSLock()
    private var _composed: [Composed] = []
    private let outcome: MessageOutcome

    public let canSendText: Bool

    public init(outcome: MessageOutcome = .sent, canSendText: Bool = true) {
        self.outcome = outcome
        self.canSendText = canSendText
    }

    public var composed: [Composed] { lock.withLock { _composed } }

    @MainActor
    public func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome {
        // A double that could reach a real person would defeat the point.
        precondition(
            recipients.allSatisfy(\.isReservedForDrama),
            "SpyMessageComposer was given a number outside Ofcom's reserved drama range: \(recipients.map(\.dialable))"
        )
        lock.withLock { _composed.append(Composed(recipients: recipients, body: body)) }
        return outcome
    }
}

public final class SpyDialler: Dialling, @unchecked Sendable {
    private let lock = NSLock()
    private var _dialled: [PhoneNumber] = []
    private let succeeds: Bool

    public init(succeeds: Bool = true) { self.succeeds = succeeds }

    public var dialled: [PhoneNumber] { lock.withLock { _dialled } }

    @MainActor
    public func dial(_ number: PhoneNumber) async -> Bool {
        precondition(
            number.isReservedForDrama,
            "SpyDialler was asked to dial \(number.dialable), which is not in the reserved drama range."
        )
        lock.withLock { _dialled.append(number) }
        return succeeds
    }
}

public final class InMemoryContactStore: TrustedContactStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var contacts: [TrustedContact]
    private let failure: (any Error)?

    public init(contacts: [TrustedContact] = [], failure: (any Error)? = nil) {
        self.contacts = contacts
        self.failure = failure
    }

    public func load() throws -> [TrustedContact] {
        if let failure { throw failure }
        return lock.withLock { contacts }
    }

    public func save(_ contacts: [TrustedContact]) throws {
        if let failure { throw failure }
        lock.withLock { self.contacts = contacts }
    }
}

public struct FixedBattery: BatteryReading {
    public let fraction: Double?
    public init(fraction: Double?) { self.fraction = fraction }
}

public struct FixedTime: TimeSource {
    public let now: Date
    public let timeZone: TimeZone
    public init(now: Date, timeZone: TimeZone = TimeZone(identifier: "Europe/London")!) {
        self.now = now
        self.timeZone = timeZone
    }
}
