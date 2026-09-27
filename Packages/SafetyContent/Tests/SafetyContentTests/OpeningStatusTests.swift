import Foundation
import Testing

@testable import SafetyContent

// Hours are evaluated in UK time. 2026-09-30 is a Wednesday; 2026-10-03 a Saturday;
// 2026-10-04 a Sunday. British Summer Time is in effect, so UK local = UTC+1, and
// every instant below is written in UTC with its UK wall-clock time alongside.

private func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
}

private let weekdaysTenToFour = Availability.schedule([OpeningWindow(days: .weekdays, openHour: 10, closeHour: 16)])

@Suite("Opening status")
struct OpeningStatusTests {

    @Test("A 24-hour line is always open")
    func allHours() {
        #expect(Availability.allHours.status(at: at("2026-10-04T02:00:00Z")) == .openNow) // Sun 03:00
    }

    @Test("A service with no published hours is unknown, not assumed open")
    func seeWebsite() {
        // Guessing "open" would send someone to a line that may not answer.
        #expect(Availability.seeWebsite.status(at: at("2026-09-30T10:00:00Z")) == .unknown)
    }

    @Test("Weekday hours: open inside, closed before, closed at the closing hour")
    func weekdayHours() {
        #expect(weekdaysTenToFour.status(at: at("2026-09-30T10:00:00Z")) == .openNow)   // Wed 11:00
        #expect(weekdaysTenToFour.status(at: at("2026-09-30T08:00:00Z")) == .closedNow) // Wed 09:00
        #expect(weekdaysTenToFour.status(at: at("2026-09-30T14:59:00Z")) == .openNow)   // Wed 15:59
        // closeHour is exclusive: a line closing at 16 is already shut at 16:00.
        #expect(weekdaysTenToFour.status(at: at("2026-09-30T15:00:00Z")) == .closedNow) // Wed 16:00
    }

    @Test("Weekday hours are closed at the weekend")
    func weekdayHoursClosedAtWeekend() {
        #expect(weekdaysTenToFour.status(at: at("2026-10-03T10:00:00Z")) == .closedNow) // Sat 11:00
        #expect(weekdaysTenToFour.status(at: at("2026-10-04T10:00:00Z")) == .closedNow) // Sun 11:00
    }

    @Test("An evening line open until midnight, every day")
    func eveningUntilMidnight() {
        // Rape Crisis Scotland's helpline runs 5pm to midnight, every day. A closing
        // hour of 24 means "until midnight", so 23:59 is open and 00:00 is not.
        let evenings = Availability.schedule([OpeningWindow(days: .everyDay, openHour: 17, closeHour: 24)])
        #expect(evenings.status(at: at("2026-10-04T22:59:00Z")) == .openNow)   // Sun 23:59
        #expect(evenings.status(at: at("2026-10-03T16:00:00Z")) == .openNow)   // Sat 17:00
        #expect(evenings.status(at: at("2026-10-03T15:59:00Z")) == .closedNow) // Sat 16:59
        #expect(evenings.status(at: at("2026-10-04T23:00:00Z")) == .closedNow) // Mon 00:00
    }

    @Test("Different weekday and weekend hours are each honoured")
    func splitWeek() {
        // Victim Support Scotland: 8am–8pm Monday to Friday, 10am–4pm at weekends.
        // Flattening that into one window would be wrong one way or the other.
        let hours = Availability.schedule([
            OpeningWindow(days: .weekdays, openHour: 8, closeHour: 20),
            OpeningWindow(days: .weekends, openHour: 10, closeHour: 16),
        ])
        #expect(hours.status(at: at("2026-09-30T18:30:00Z")) == .openNow)   // Wed 19:30
        #expect(hours.status(at: at("2026-10-03T18:30:00Z")) == .closedNow) // Sat 19:30 — weekend closes at 16
    }

    @Test("Weekend window does not open early")
    func weekendDoesNotOpenEarly() {
        let hours = Availability.schedule([
            OpeningWindow(days: .weekdays, openHour: 8, closeHour: 20),
            OpeningWindow(days: .weekends, openHour: 10, closeHour: 16),
        ])
        #expect(hours.status(at: at("2026-10-03T08:30:00Z")) == .closedNow) // Sat 09:30
        #expect(hours.status(at: at("2026-10-03T09:30:00Z")) == .openNow)   // Sat 10:30
    }

    @Test("Hours are UK hours regardless of where the user is")
    func usesUKTimeNotDeviceTime() {
        // A UK survivor in Sydney at 8pm local is looking at 11:00 on a Wednesday in
        // the UK, so the line IS open. Telling them it is shut would be the more
        // harmful error, which is why the default evaluates in the service's zone.
        let instant = at("2026-09-30T10:00:00Z")
        #expect(weekdaysTenToFour.status(at: instant) == .openNow)
        #expect(weekdaysTenToFour.status(at: instant, in: TimeZone(identifier: "Australia/Sydney")!) == .closedNow)
    }

    @Test("Handles the GMT/BST changeover without drifting an hour")
    func acrossDaylightSaving() {
        // The UK returns to GMT on 2026-10-25. Monday 10:30 GMT afterwards must read
        // as open; Monday 09:30 BST before it must read as closed.
        #expect(weekdaysTenToFour.status(at: at("2026-10-26T10:30:00Z")) == .openNow)
        #expect(weekdaysTenToFour.status(at: at("2026-10-19T08:30:00Z")) == .closedNow)
    }
}

@Suite("Availability decoding")
struct AvailabilityDecodingTests {

    private func decode(_ json: String) throws -> Availability {
        try JSONDecoder().decode(Availability.self, from: Data(json.utf8))
    }

    @Test("Bare strings decode")
    func bareStrings() throws {
        #expect(try decode(#""allHours""#) == .allHours)
        #expect(try decode(#""seeWebsite""#) == .seeWebsite)
    }

    @Test("A schedule decodes, including split weeks")
    func schedule() throws {
        let decoded = try decode(#"{"schedule":[{"days":"weekdays","openHour":8,"closeHour":20},{"days":"weekends","openHour":10,"closeHour":16}]}"#)
        #expect(decoded == .schedule([
            OpeningWindow(days: .weekdays, openHour: 8, closeHour: 20),
            OpeningWindow(days: .weekends, openHour: 10, closeHour: 16),
        ]))
    }

    @Test("Implausible hours are rejected rather than silently accepted")
    func rejectsNonsense() {
        // A typo such as openHour 17, closeHour 7 would otherwise make a line read as
        // permanently closed — a silent content error with real consequences.
        #expect(throws: (any Error).self) { try decode(#"{"schedule":[{"days":"weekdays","openHour":17,"closeHour":7}]}"#) }
        #expect(throws: (any Error).self) { try decode(#"{"schedule":[{"days":"weekdays","openHour":9,"closeHour":25}]}"#) }
        #expect(throws: (any Error).self) { try decode(#"{"schedule":[]}"#) }
        #expect(throws: (any Error).self) { try decode(#""sometimes""#) }
    }

    @Test("Round-trips without change")
    func roundTrip() throws {
        let original = Availability.schedule([OpeningWindow(days: .everyDay, openHour: 17, closeHour: 24)])
        let decoded = try JSONDecoder().decode(Availability.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
