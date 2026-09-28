import SafetyContent
import Testing

@testable import SafetyUI

/// `help.noPhone` ("This service has no phone line.") must survive
/// for Women's Aid on Get help — the one entry it exists for — and must not appear
/// for a refuge directory in the refuge list, where a phoneless `.information` entry
/// was never a phone line to begin with.
@Suite("Service row — the no-phone line")
struct ServiceRowTests {

    @Test("Women's Aid, an .information entry on Get help, still shows the no-phone line")
    func womensAidOnHelp() {
        // Get help does not pass `showsNoPhoneLine`, so it keeps the default (`true`).
        #expect(ServiceRow.shouldShowNoPhoneLine(kind: .information, showsNoPhoneLine: true))
    }

    @Test("A refuge directory, also .information, does not — it was never a phone line")
    func refugeDirectoryInRefugesList() {
        // RefugesScreen passes `showsNoPhoneLine: false`.
        #expect(!ServiceRow.shouldShowNoPhoneLine(kind: .information, showsNoPhoneLine: false))
    }

    @Test("A web-only reporting route never shows the no-phone line, on either screen")
    func reportingRouteNeverShowsIt() {
        #expect(!ServiceRow.shouldShowNoPhoneLine(kind: .reporting, showsNoPhoneLine: true))
        #expect(!ServiceRow.shouldShowNoPhoneLine(kind: .reporting, showsNoPhoneLine: false))
    }

    @Test("A helpline or charity with no phone would still be told so, on Get help")
    func helplineOrCharityOnHelp() {
        #expect(ServiceRow.shouldShowNoPhoneLine(kind: .helpline, showsNoPhoneLine: true))
        #expect(ServiceRow.shouldShowNoPhoneLine(kind: .charity, showsNoPhoneLine: true))
    }
}
