import Foundation
import Observation
import SafetyDomain
import SafetyServices

/// Raising an alert: who it goes to, where the person is, and what happened.
///
/// Every path ends in a `finished` outcome the screen shows. Nothing here can fail
/// silently, and nothing claims more than is known: "sent" means handed to Messages,
/// because iOS reports nothing about delivery.
@MainActor
@Observable
public final class AlertModel {

    public enum Outcome: Equatable, Sendable {
        /// The person tapped Send in Messages.
        case handedToMessages(includedLocation: Bool)
        case cancelled
        case failed
        /// No SIM, or messaging is restricted. The screen offers calls instead.
        case cannotText
        case needsContacts
        case contactsUnreadable
    }

    public enum Phase: Equatable, Sendable {
        case idle
        case locating
        case composing
        case finished(Outcome)
    }

    public private(set) var phase: Phase = .idle
    /// Who the alert was for, kept so the failure states can offer to call them.
    public private(set) var recipients: [AlertRecipient] = []
    /// Whether the current result was raised in Test Mode — so its drama numbers, or
    /// its real ones, are never offered once the mode has changed. See
    /// `callableRecipients(testModeIsOn:)`.
    public private(set) var raisedInTestMode = false

    /// `true` for as long as a `raise` is in flight, from the moment it is called
    /// to the moment it returns — tracked independently of `phase`, which exists
    /// only to drive the screen. `phase` stays `.idle`/`.finished` across some
    /// awaits (for example when location is not authorised), so relying on it here
    /// would let a second tap slip through a future suspension point and stack a
    /// second composer.
    private var inFlight = false

    public var isBusy: Bool { inFlight }

    /// How long `raise` waits for a location before sending without one.
    public static let defaultLocationTimeout: Duration = .seconds(3)

    private let services: Services
    private let strings: AlertStrings
    private let locale: Locale
    private let locationTimeout: Duration

    public init(
        services: Services,
        strings: AlertStrings,
        locale: Locale = .autoupdatingCurrent,
        locationTimeout: Duration = defaultLocationTimeout
    ) {
        self.services = services
        self.strings = strings
        self.locale = locale
        self.locationTimeout = locationTimeout
    }

    public func raise(contacts: [TrustedContact], contactsReadable: Bool, testMode: Bool) async {
        // A second tap while the first is still working would stack two composers.
        // Set before any `await`, so nothing can interleave between the check and
        // the flag being raised.
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }

        guard contactsReadable else {
            recipients = []
            raisedInTestMode = testMode
            return finish(.contactsUnreadable)
        }

        switch AlertPlanner.plan(contacts: contacts, testMode: testMode) {
        case .needsContacts:
            recipients = []
            raisedInTestMode = testMode
            finish(.needsContacts)

        case let .ready(planned, isTest):
            recipients = planned
            raisedInTestMode = isTest
            // Checked before looking for a location, so someone with no SIM is sent
            // straight to calling instead of waiting to be told.
            guard services.messages.canSendText else { return finish(.cannotText) }

            let fix = await locationSnapshot()
            let context = AlertContext(
                sentAt: services.time.now,
                location: fix,
                batteryFraction: services.battery.fraction,
                isTest: isTest
            )
            let body = AlertMessageRenderer.render(context, strings: strings, locale: locale, timeZone: services.time.timeZone)

            phase = .composing
            switch await services.messages.compose(recipients: planned.map(\.number), body: body) {
            case .sent: finish(.handedToMessages(includedLocation: context.usableLocation != nil))
            case .cancelled: finish(.cancelled)
            case .failed: finish(.failed)
            case .unavailable: finish(.cannotText)
            }
        }
    }

    /// Clears a finished outcome, and with it everyone it offered to call. Does
    /// nothing while an alert is being prepared.
    public func reset() {
        guard !isBusy else { return }
        phase = .idle
        recipients = []
        raisedInTestMode = false
    }

    /// Who the result may offer to call, given whether Test Mode is on *now*.
    ///
    /// Nobody, if the mode has changed since the alert was raised. A real result
    /// seen in Test Mode would offer a real person's number under a banner that
    /// promises nobody will be contacted; a rehearsal seen after Test Mode switched
    /// off would offer "Call Alice" on a drama number that reaches no one.
    public func callableRecipients(testModeIsOn: Bool) -> [AlertRecipient] {
        raisedInTestMode == testModeIsOn ? recipients : []
    }

    /// Reads a location only if the person has already allowed it at full accuracy.
    ///
    /// Never prompts. A permission dialog in the middle of raising an alert is a
    /// block, and the alert must never block on location. Permission is asked from
    /// the Alert tab's own "Allow location" button instead.
    private func locationSnapshot() async -> LocationFix? {
        let location = services.location
        guard location.authorization == .authorizedWhenInUse else { return nil }
        phase = .locating
        let timeout = locationTimeout
        // The provider promises to honour the timeout. This does not rely on it.
        return await firstResult(within: timeout) { await location.currentFix(timeout: timeout) }
    }

    private func finish(_ outcome: Outcome) {
        phase = .finished(outcome)
    }
}
