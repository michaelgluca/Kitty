import Foundation
import Testing

@testable import SafetyContent

@Suite("Opening status")
struct OpeningStatusTests {

    /// Builds an instant from UK wall-clock time, so the tests read as a person would
    /// describe them.
    private func ukTime(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    // 2026-09-30 is a Wednesday; 2026-10-03 a Saturday; 2026-10-04 a Sunday.
    // British Summer Time is in effect, so UK local is UTC+1.

    @Test("A 24-hour line is always open")
    func allHours() {
        #expect(Availability.allHours.status(at: ukTime("2026-10-04T03:00:00Z")) == .openNow)
    }

    @Test("A service with no published hours is unknown, not assumed open")
    func seeWebsite() {
        // Guessing "open" here would send someone to a service that may not answer.
        #expect(Availability.seeWebsite.status(at: ukTime("2026-09-30T11:00:00Z")) == .unknown)
    }

    @Test("Open during published weekday hours")
    func openMidweek() {
        // Wednesday 11:00 BST == 10:00Z
        #expect(Availability.weekdays(openHour: 10, closeHour: 16)
            .status(at: ukTime("2026-09-30T10:00:00Z")) == .openNow)
    }

    @Test("Closed before opening and at the closing hour")
    func closedOutsideHours() {
        let hours = Availability.weekdays(openHour: 10, closeHour: 16)
        // 09:00 BST
        #expect(hours.status(at: ukTime("2026-09-30T08:00:00Z")) == .closedNow)
        // 16:00 BST exactly — closeHour is exclusive, so the line is already shut.
        #expect(hours.status(at: ukTime("2026-09-30T15:00:00Z")) == .closedNow)
        // 15:59 BST
        #expect(hours.status(at: ukTime("2026-09-30T14:59:00Z")) == .openNow)
    }

    @Test("Closed at the weekend")
    func closedAtWeekend() {
        let hours = Availability.weekdays(openHour: 10, closeHour: 16)
        // Saturday 11:00 BST
        #expect(hours.status(at: ukTime("2026-10-03T10:00:00Z")) == .closedNow)
        // Sunday 11:00 BST
        #expect(hours.status(at: ukTime("2026-10-04T10:00:00Z")) == .closedNow)
    }

    @Test("Hours are UK hours regardless of where the user is")
    func usesUKTimeNotDeviceTime() {
        // A UK survivor in Sydney checking at 8pm their time. That is 11:00 in the
        // UK on a Wednesday, so the line IS open — telling them it is shut would be
        // the more harmful error.
        let hours = Availability.weekdays(openHour: 10, closeHour: 16)
        let instant = ukTime("2026-09-30T10:00:00Z")
        #expect(hours.status(at: instant) == .openNow)

        // Explicitly evaluating in the traveller's own zone would give the wrong
        // answer, which is exactly why the default is the service's zone.
        let sydney = TimeZone(identifier: "Australia/Sydney")!
        #expect(hours.status(at: instant, in: sydney) == .closedNow)
    }

    @Test("Handles the GMT/BST boundary without drifting an hour")
    func acrossDaylightSaving() {
        // 2026-10-25 is the Sunday the UK returns to GMT. Pick the Monday after, at
        // 10:30 GMT, which must read as open under 10-16.
        let hours = Availability.weekdays(openHour: 10, closeHour: 16)
        #expect(hours.status(at: ukTime("2026-10-26T10:30:00Z")) == .openNow)
        // And the Monday before the change, 10:30 BST == 09:30Z, must read as closed.
        #expect(hours.status(at: ukTime("2026-10-19T08:30:00Z")) == .closedNow)
    }
}
