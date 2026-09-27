import XCTest

/// Tapping a service's Call button must confirm THAT service, with THAT number.
///
/// Written after coordinate taps on device produced a confirmation naming a
/// different service from the one intended. This test settled it: finding each
/// button by its accessibility label and waiting until it is hittable, the original
/// code confirmed the right service every time. The mismatch came from tapping a
/// list that was still scrolling, not from the app. The test stays as a guard, and
/// it also checks the confirmation shows the exact number that will be dialled —
/// which the original dialog did not.
///
/// Nothing here dials. The test dismisses every confirmation without confirming.
//
// Swift 6 strict mode. The class is not actor-isolated, because XCTestCase's own
// initialisers are not; the test methods, which drive the MainActor-isolated
// XCUIApplication, are marked @MainActor instead. No setUp is overridden for the
// same reason.
final class HelpCallTests: XCTestCase {

    @MainActor
    private func launchOnHelp(locale: String = "en_GB") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Pin the region rather than depend on the simulator's locale.
        app.launchArguments += ["-AppleLocale", locale, "-AppleLanguages", "(en)"]
        app.launch()
        app.tabBars.buttons["Get help"].tap()
        return app
    }

    @MainActor
    private func assertConfirms(
        number: String, service: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let button = app.buttons["Call \(number)"]
        app.reveal(button, file: file, line: line)
        button.tap()

        // The title names the service that was tapped...
        let title = app.staticTexts["Call \(service)?"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Tapping Call \(number) did not confirm \(service)", file: file, line: line)

        // ...and the dialog's OWN message shows the number that will be dialled.
        //
        // Scoped to the message text deliberately. An earlier version matched the
        // number anywhere on screen, which the list behind the dialog also shows — so
        // it passed even against a dialog that never displayed the number at all.
        let message = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@",
            "This will open your phone app to call", number
        )).firstMatch
        XCTAssertTrue(message.exists,
                      "Confirmation for \(service) does not show \(number)", file: file, line: line)

        app.dismissConfirmation()
        XCTAssertTrue(title.waitForNonExistence(timeout: 3), "Confirmation did not dismiss", file: file, line: line)
    }

    // MARK: - Guideline 1.7: crime reporting is UK-only

    /// British Transport Police's text button exists only in the reporting section,
    /// so it stands in for "reporting is on screen".
    private let reportingMarker = "Text 61016"

    @MainActor
    func testReportingIsShownInTheUK() {
        let app = launchOnHelp(locale: "en_GB")
        app.reveal(app.buttons[reportingMarker])
    }

    @MainActor
    func testReportingIsWithheldOutsideTheUK() {
        let app = launchOnHelp(locale: "en_US")
        XCTAssertTrue(app.staticTexts["Written for the UK"].waitForExistence(timeout: 3),
                      "The non-UK notice should be shown")

        // "Not found" means nothing unless the whole list was scrolled. The guides come
        // after where reporting would sit, so reaching the last guide proves the test
        // looked everywhere reporting could have been.
        let lastGuide = app.staticTexts["Safety Check"]
        var attempts = 0
        while !(lastGuide.exists && lastGuide.isHittable) && attempts < 40 {
            XCTAssertFalse(app.buttons[reportingMarker].exists, "Crime reporting shown outside the UK")
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        XCTAssertTrue(lastGuide.isHittable, "Never reached the end of the list, so the check proves nothing")
        XCTAssertFalse(app.buttons[reportingMarker].exists, "Crime reporting shown outside the UK")
    }

    // MARK: - Calling

    /// Alternates between services, so a dialog that belonged to the PREVIOUS tap
    /// would show up as a mismatch.
    @MainActor
    func testEachCallButtonConfirmsItsOwnServiceAndNumber() {
        let app = launchOnHelp()
        assertConfirms(number: "0808 80 10 800", service: "Live Fear Free", in: app)
        assertConfirms(number: "0800 027 1234", service: "Scotland's Domestic Abuse and Forced Marriage Helpline", in: app)
        assertConfirms(number: "0808 80 10 800", service: "Live Fear Free", in: app)
        assertConfirms(number: "0808 802 1414", service: "Domestic and Sexual Abuse Helpline", in: app)
        assertConfirms(number: "0808 801 0302", service: "Rape Crisis Scotland Helpline", in: app)
        assertConfirms(number: "0800 389 4424", service: "The Rowan Sexual Assault Referral Centre", in: app)
        assertConfirms(number: "0808 801 0302", service: "Rape Crisis Scotland Helpline", in: app)
    }
}
