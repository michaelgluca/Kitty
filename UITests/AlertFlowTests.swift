import XCTest

/// The alert path end to end.
///
/// Every test launches with `-kitty.uiTest`, which gives the app its own Keychain
/// item for trusted contacts, so a developer's real list is never touched. The
/// switches exist only in debug builds. Seeded contacts are on Ofcom drama numbers.
///
/// Nothing here dials 999. The one test that opens the real 999 confirmation only
/// ever cancels it, and runs only on a simulator, which cannot place calls.
//
// Swift 6 strict mode: the class is nonisolated because XCTestCase's initialisers
// are; the test methods drive the MainActor-isolated XCUIApplication, so they are
// marked @MainActor. See HelpCallTests.
final class AlertFlowTests: XCTestCase {

    private static var onSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    @MainActor
    private func launch(_ switches: [String] = [], locale: String = "en_GB") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", locale, "-AppleLanguages", "(en)", "-kitty.uiTest"] + switches
        app.launch()
        return app
    }

    @MainActor
    private func turnOnTestMode(in app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        let toggle = app.switches["settings.testMode"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        // Tap the switch itself: tapping a Form row's label does not flip a Toggle
        // on iOS 17 and later.
        let knob = toggle.switches.firstMatch
        (knob.exists ? knob : toggle).tap()
        if toggle.value as? String != "1" {
            // On iOS 26/27's Liquid Glass switch, a very short synthetic tap can be
            // swallowed without flipping the control. Fall back to a coordinate
            // press-and-drag across the switch, which reliably reproduces a real
            // finger dragging the knob across.
            let target = knob.exists ? knob : toggle
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        }
        XCTAssertEqual(toggle.value as? String, "1", "Test Mode did not switch on")
        app.tabBars.buttons["Alert"].tap()
    }

    @MainActor
    private func text(containing fragment: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    /// Raises an alert to the seeded contacts and waits for the simulator's "cannot
    /// send text messages" card, which offers a call per contact. Skips if this
    /// simulator can text: Messages opens instead, and it is closed without sending.
    @MainActor
    private func raiseToCannotText(in app: XCUIApplication) throws -> XCUIElement {
        app.buttons["alert.button"].tap()

        let result = app.staticTexts["alert.result"]
        let closeComposer = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Close"])).firstMatch
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline && !result.exists && !closeComposer.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        if !result.exists {
            XCTAssertTrue(closeComposer.exists, "Neither a result nor the Messages sheet appeared")
            closeComposer.tap()
            throw XCTSkip("This simulator can send texts, so the cannot-text card is not reachable here.")
        }
        XCTAssertTrue(result.label.contains("cannot send text messages"), result.label)
        return result
    }

    // MARK: - US-1: alert my people

    @MainActor
    func testAlertWithNoContactsOpensSetup() {
        let app = launch(["-kitty.resetContacts"])
        app.buttons["alert.button"].tap()
        XCTAssertTrue(app.buttons["contacts.add"].waitForExistence(timeout: 5),
                      "With no contacts, the alert must open setup rather than fail")
        XCTAssertTrue(app.navigationBars["Trusted contacts"].exists)
    }

    /// Pins a real bug found on the simulator: tapping the alert button, going back
    /// from Trusted contacts, and tapping the alert button again must open Trusted
    /// contacts again — not silently do nothing because the navigation state thinks
    /// it is already showing.
    @MainActor
    func testAlertTappedAgainWithNoContactsOpensSetupAgain() {
        let app = launch(["-kitty.resetContacts"])

        app.buttons["alert.button"].tap()
        XCTAssertTrue(app.navigationBars["Trusted contacts"].waitForExistence(timeout: 5),
                      "The first tap must open Trusted contacts")

        app.navigationBars["Trusted contacts"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["alert.button"].waitForExistence(timeout: 5),
                      "Going back must return to the Alert tab")

        app.buttons["alert.button"].tap()
        XCTAssertTrue(app.navigationBars["Trusted contacts"].waitForExistence(timeout: 5),
                      "The second tap, with contacts still empty, must open Trusted contacts again")
    }

    @MainActor
    func testAlertThatCannotBeTextedIsReportedWithAWayForward() throws {
        try XCTSkipUnless(Self.onSimulator, "Relies on the simulator's Messages behaviour.")
        let app = launch(["-kitty.resetContacts", "-kitty.seedContacts"])
        app.buttons["alert.button"].tap()

        // The simulator normally cannot send texts. If this one can, Messages opens
        // instead: close it without sending, and the app must say it was not sent.
        let result = app.staticTexts["alert.result"]
        let closeComposer = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Close"])).firstMatch
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline && !result.exists && !closeComposer.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        if !result.exists {
            XCTAssertTrue(closeComposer.exists, "Neither a result nor the Messages sheet appeared")
            closeComposer.tap()
            XCTAssertTrue(result.waitForExistence(timeout: 5))
            XCTAssertTrue(result.label.hasPrefix("Not sent"), "Closing Messages must be reported, not shown as sent: \(result.label)")
            return
        }

        XCTAssertTrue(result.label.contains("cannot send text messages"), result.label)
        XCTAssertTrue(app.buttons["Call Alice (07700 900001)"].exists, "The person must be offered a call instead")
        XCTAssertTrue(app.buttons["Call Bob (07700 900002)"].exists)
    }

    /// Spec §7: the alert control is in thumb reach and one tap from launch at every
    /// text size — never below the fold, and never pushed down by the Test Mode
    /// banner.
    @MainActor
    func testAlertButtonIsInReachWithoutScrollingAtTheLargestTextSize() {
        let app = launch([
            "-kitty.resetContacts",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        let button = app.buttons["alert.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(button.isHittable, "The alert button must be on screen at launch, without scrolling")
        XCTAssertGreaterThan(button.frame.midY, window.midY, "The alert button must sit in the lower half, in thumb reach")

        turnOnTestMode(in: app)
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForExistence(timeout: 3))
        XCTAssertTrue(button.isHittable, "The Test Mode banner must not push the alert button off screen")
        XCTAssertGreaterThan(button.frame.midY, window.midY, "The alert button must stay in thumb reach in Test Mode")
    }

    /// A real alert's "Call Alice" must not survive Test Mode being turned on: under
    /// the banner that promises nobody will be contacted, it would call a real person.
    @MainActor
    func testTurningTestModeOnClearsARealAlertsCallButtons() throws {
        try XCTSkipUnless(Self.onSimulator, "Relies on the simulator's Messages behaviour.")
        let app = launch(["-kitty.resetContacts", "-kitty.seedContacts"])
        let result = try raiseToCannotText(in: app)
        let callAlice = app.buttons["Call Alice (07700 900001)"]
        XCTAssertTrue(callAlice.exists, "The real alert must first offer a call")

        turnOnTestMode(in: app)
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForExistence(timeout: 3))

        XCTAssertTrue(result.waitForNonExistence(timeout: 3),
                      "A result raised outside Test Mode must be cleared when Test Mode is turned on")
        XCTAssertFalse(callAlice.exists, "Test Mode must never offer a call to a contact from a real alert")
        XCTAssertFalse(app.buttons["Call Bob (07700 900002)"].exists)
    }

    /// And the reverse: a rehearsal's drama-number "Call Alice" must not survive Test
    /// Mode being turned off, or a real emergency would be offered a number that
    /// reaches nobody.
    @MainActor
    func testTurningTestModeOffClearsARehearsalsCallButtons() throws {
        try XCTSkipUnless(Self.onSimulator, "Relies on the simulator's Messages behaviour.")
        let app = launch(["-kitty.resetContacts", "-kitty.seedContacts"])
        turnOnTestMode(in: app)
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForExistence(timeout: 3))

        let result = try raiseToCannotText(in: app)
        let callAlice = app.buttons["Call Alice (07700 900001)"]
        XCTAssertTrue(callAlice.exists, "The rehearsal must first offer a call")

        let turnOff = app.buttons["testMode.turnOff"]
        app.reveal(turnOff, towardsTop: true)
        turnOff.tap()
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForNonExistence(timeout: 3))

        XCTAssertTrue(result.waitForNonExistence(timeout: 3),
                      "A rehearsal's result must be cleared when Test Mode is turned off")
        XCTAssertFalse(callAlice.exists, "Outside Test Mode, a rehearsal's drama number must never be offered")
        XCTAssertFalse(app.buttons["Call Bob (07700 900002)"].exists)
    }

    /// Removing a contact clears a result that offered to call them.
    @MainActor
    func testRemovingAContactClearsAResultOfferingToCallThem() throws {
        try XCTSkipUnless(Self.onSimulator, "Relies on the simulator's Messages behaviour.")
        let app = launch(["-kitty.resetContacts", "-kitty.seedContacts"])
        let result = try raiseToCannotText(in: app)
        XCTAssertTrue(app.buttons["Call Alice (07700 900001)"].exists)

        let contacts = app.buttons["alert.contacts"]
        app.reveal(contacts, towardsTop: true)
        contacts.tap()
        let removeAlice = app.buttons["contact.remove.Alice"]
        XCTAssertTrue(removeAlice.waitForExistence(timeout: 3))
        app.reveal(removeAlice)
        removeAlice.tap()
        XCTAssertTrue(app.staticTexts["Remove Alice?"].waitForExistence(timeout: 3))
        app.buttons["Remove from trusted contacts"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["contact.Alice"].waitForNonExistence(timeout: 3))

        app.navigationBars["Trusted contacts"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["alert.button"].waitForExistence(timeout: 5))
        XCTAssertFalse(result.exists, "A result offering to call a removed contact must be cleared")
        XCTAssertFalse(app.buttons["Call Alice (07700 900001)"].exists)
    }

    // MARK: - US-3: call for help

    @MainActor
    func testEmergencyCallAlwaysAsksFirst() throws {
        try XCTSkipUnless(Self.onSimulator, "Opens the real 999 confirmation, so it runs only where no call can be placed.")
        let app = launch(["-kitty.resetContacts"])

        let call = app.buttons["emergency.call"]
        app.reveal(call)
        XCTAssertEqual(call.label, "Call 999")
        call.tap()

        XCTAssertTrue(app.staticTexts["Call 999?"].waitForExistence(timeout: 3), "999 must always be confirmed first")
        XCTAssertTrue(text(containing: "shares its location", in: app).exists,
                      "The confirmation must say the iPhone shares its location during the call")

        // Never confirm. Cancel only.
        app.dismissConfirmation()
        XCTAssertTrue(app.staticTexts["Call 999?"].waitForNonExistence(timeout: 3))
    }

    /// If the bundled content ever failed to load, the UK Alert tab has no 999 button
    /// and must say so, rather than leave a gap with no explanation.
    @MainActor
    func testMissingContentSaysThe999ButtonCouldNotBeLoaded() {
        let app = launch(["-kitty.resetContacts", "-kitty.withoutContent"])
        XCTAssertTrue(app.buttons["alert.button"].waitForExistence(timeout: 5))

        let line = text(containing: "The 999 button could not be loaded", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 3), "The missing 999 button must be explained")
        app.reveal(line)
        XCTAssertFalse(app.buttons["emergency.call"].exists, "With no content there is no number to dial, so no 999 button")
    }

    @MainActor
    func testNoEmergencyCallButtonOutsideTheUK() {
        let app = launch(["-kitty.resetContacts"], locale: "en_US")
        XCTAssertTrue(app.buttons["alert.button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["emergency.call"].exists, "999 does not work outside the UK and must not be offered")
        XCTAssertTrue(text(containing: "local emergency number", in: app).exists)
    }

    // MARK: - Test Mode

    @MainActor
    func testTestModeIsUnmistakableAndNeverDials999() {
        let app = launch(["-kitty.resetContacts", "-kitty.seedContacts"])
        turnOnTestMode(in: app)
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForExistence(timeout: 3),
                      "Test Mode must be announced on the Alert tab")

        let call = app.buttons["emergency.call"]
        app.reveal(call)
        XCTAssertTrue(call.label.contains("Test Mode"), call.label)
        call.tap()

        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Test Mode: this will call 07700 900999")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 3), "The confirmation must name the stand-in number")

        if Self.onSimulator {
            // Safe to confirm: the number is in Ofcom's drama range, and a simulator
            // cannot place calls. The app must say so, naming the number it tried.
            app.buttons["Call"].tap()
            XCTAssertTrue(text(containing: "07700 900999", in: app).waitForExistence(timeout: 5))
            app.buttons["OK"].tap()
        } else {
            app.dismissConfirmation()
        }
    }

    @MainActor
    func testHelpScreenCallsUseTheStandInDuringTestMode() {
        let app = launch(["-kitty.resetContacts"])
        turnOnTestMode(in: app)
        app.tabBars.buttons["Get help"].tap()
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForExistence(timeout: 3),
                      "Test Mode must be announced on the Help tab")

        let call = app.buttons["Call 0808 80 10 800"]
        app.reveal(call)
        call.tap()
        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Test Mode: this will call 07700 900000")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 3), "A helpline call in Test Mode must go to the stand-in")
        XCTAssertTrue(message.label.contains("0808 80 10 800"), "It must name the number it replaces")
        app.dismissConfirmation()
    }

    @MainActor
    func testTestModeSwitchesOffWhenYouLeaveTheApp() {
        let app = launch(["-kitty.resetContacts"])
        turnOnTestMode(in: app)
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.buttons["alert.button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Test Mode is on"].exists, "Test Mode must not outlive leaving the app")
    }

    /// The banner's own "Turn off Test Mode" button must be a real, readable,
    /// hittable control — not just a tap target that happens to work — and using it
    /// must actually turn Test Mode off everywhere it is shown.
    @MainActor
    func testTurnOffTestModeButtonIsReadableAndWorks() {
        let app = launch(["-kitty.resetContacts"])
        turnOnTestMode(in: app)
        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForExistence(timeout: 3))

        let turnOff = app.buttons["testMode.turnOff"]
        XCTAssertTrue(turnOff.exists)
        XCTAssertTrue(turnOff.isHittable)
        XCTAssertEqual(turnOff.label, "Turn off Test Mode")

        turnOff.tap()

        XCTAssertTrue(app.staticTexts["Test Mode is on"].waitForNonExistence(timeout: 3),
                      "The banner must disappear once Test Mode is off")
        let call = app.buttons["emergency.call"]
        app.reveal(call)
        XCTAssertFalse(call.label.contains("Test Mode"), call.label)
    }

    // MARK: - US-2: choose my people

    @MainActor
    func testRemovingAContactAsksFirstAndIsRemembered() {
        var app = launch(["-kitty.resetContacts", "-kitty.seedContacts"])
        app.buttons["alert.contacts"].tap()

        let alice = app.descendants(matching: .any)["contact.Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 3))

        // Removal goes through the visible per-row button, not the swipe action.
        // A swipe-left-then-swipe-right-to-collapse path was tried here to also cover
        // swipe-to-delete, but the collapse animation raced the follow-up tap: the
        // touch sometimes landed while the row was still sliding back, hitting
        // nothing and leaving the confirmation dialog never shown. That made the
        // test flaky rather than the app wrong, so the swipe path was dropped; the
        // swipe action itself is still exercised implicitly, since it drives the
        // same `pendingRemoval` state as this button.
        let removeAlice = app.buttons["contact.remove.Alice"]
        app.reveal(removeAlice)
        XCTAssertEqual(removeAlice.label, "Remove Alice")
        removeAlice.tap()

        XCTAssertTrue(app.staticTexts["Remove Alice?"].waitForExistence(timeout: 3), "Removal must be confirmed")
        app.buttons["Remove from trusted contacts"].tap()
        XCTAssertTrue(alice.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["contact.Bob"].exists)

        // Relaunch without resetting: what was saved must still be there.
        app.terminate()
        app = launch()
        app.buttons["alert.contacts"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["contact.Bob"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["contact.Alice"].exists, "The removal was not saved")
    }
}
