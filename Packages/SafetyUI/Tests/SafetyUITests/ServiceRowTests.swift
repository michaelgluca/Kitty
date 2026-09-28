import SafetyContent
import Testing

@testable import SafetyUI

/// `help.noPhone` ("This service has no phone line.") must survive
/// for Women's Aid on Get help — the one entry it exists for — and must not appear
/// for a refuge directory in the refuge list, where a phoneless `.information` entry
/// was never a phone line to begin with.
@MainActor
@Suite("Service row — the no-phone line")
struct ServiceRowTests {

    @Test("The no-phone line shows only where someone might look for a number", arguments: [
        // Women's Aid on Get help: the one entry it exists for. Get help keeps the default.
        (ServiceKind.information, true, true),
        // A refuge directory in the refuge list, which passes false: never a phone line.
        (.information, false, false),
        // A web-only reporting route never needs telling, on either screen.
        (.reporting, true, false),
        (.reporting, false, false),
        // A helpline or charity with no phone would still be told so, on Get help.
        (.helpline, true, true),
        (.charity, true, true),
    ])
    func noPhoneLine(kind: ServiceKind, showsNoPhoneLine: Bool, expected: Bool) {
        #expect(ServiceRow.shouldShowNoPhoneLine(kind: kind, showsNoPhoneLine: showsNoPhoneLine) == expected)
    }
}
