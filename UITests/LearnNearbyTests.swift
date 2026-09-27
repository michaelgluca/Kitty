import XCTest

/// The Learn and Nearby tabs end to end. Nearby tests use `-kitty.stubNearby`, a
/// DEBUG-only fixed location and station, so they need no network or real location.
//
// Swift 6 strict mode: see HelpCallTests for why the class is nonisolated and the
// methods are @MainActor.
final class LearnNearbyTests: XCTestCase {

    @MainActor
    private func launch(_ switches: [String] = [], locale: String = "en_GB", resetLocation: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        if resetLocation { app.resetAuthorizationStatus(for: .location) }
        app.launchArguments += ["-AppleLocale", locale, "-AppleLanguages", "(en)", "-kitty.uiTest", "-kitty.resetNation"] + switches
        app.launch()
        return app
    }

    @MainActor
    private func anything(containing fragment: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    // MARK: - Learn

    @MainActor
    func testRightsTopicSaysWhereEachPointApplies() {
        let app = launch()
        app.tabBars.buttons["Learn"].tap()
        let topic = app.buttons["learn.rights.what-counts-as-domestic-abuse"]
        app.reveal(topic)
        topic.tap()

        XCTAssertTrue(anything(containing: "Applies ", in: app).waitForExistence(timeout: 3),
                      "Every point must say which nations it applies in")
        let disclaimer = anything(containing: "not legal advice", in: app)
        app.reveal(disclaimer)
        XCTAssertTrue(disclaimer.exists)
    }

    @MainActor
    func testIPhoneFeatureShowsItsSetupSteps() {
        let app = launch()
        app.tabBars.buttons["Learn"].tap()
        let feature = app.buttons["learn.feature.check-in"]
        app.reveal(feature)
        feature.tap()
        XCTAssertTrue(app.staticTexts["Set it up"].waitForExistence(timeout: 3))
        // Each step's accessibility label comes from the "Step %1$d: %2$@" catalogue
        // key (Task 7), not from a bare "1" static text: a bare Label whose icon is
        // just the step number is not read out by VoiceOver on its own, and the
        // number is not exposed as its own static text once the label is set.
        XCTAssertTrue(anything(containing: "Step 1: ", in: app).waitForExistence(timeout: 3), "Steps are numbered")
    }

    @MainActor
    func testHelpLinksToTheIPhoneFeatures() {
        let app = launch()
        app.tabBars.buttons["Get help"].tap()
        let link = app.buttons["help.features.link"]
        app.reveal(link)
        link.tap()
        XCTAssertTrue(app.buttons["learn.feature.emergency-sos"].waitForExistence(timeout: 3))
    }

    /// Task 8's review: with no content pack, the Learn tab must say so, never show
    /// an empty list, and the Refuges link — reachable from Nearby regardless of the
    /// pack — must do the same rather than a silent empty screen.
    @MainActor
    func testLearnAndRefugesShowUnavailableNeverAnEmptyListWithoutContent() {
        let app = launch(["-kitty.withoutContent", "-kitty.stubNearby"])

        app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.staticTexts["Information could not be loaded"].waitForExistence(timeout: 3),
                      "Learn must say content could not be loaded, never show an empty list")
        XCTAssertFalse(app.buttons["learn.rights.what-counts-as-domestic-abuse"].exists)

        app.tabBars.buttons["Nearby"].tap()
        let link = app.buttons["nearby.refuges"]
        app.reveal(link)
        link.tap()
        XCTAssertTrue(app.staticTexts["Information could not be loaded"].waitForExistence(timeout: 3),
                      "Refuges must say content could not be loaded, never show an empty list")
    }

    // MARK: - Nearby

    @MainActor
    func testNearbyAsksForLocationBeforeShowingAnything() {
        let app = launch(resetLocation: true)
        app.tabBars.buttons["Nearby"].tap()
        XCTAssertTrue(app.buttons["nearby.allow"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["nearby.map"].exists, "No map before there is a real location")
    }

    @MainActor
    func testNearbyShowsTheNearestStationWithDirections() {
        let app = launch(["-kitty.stubNearby"])
        app.tabBars.buttons["Nearby"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["nearby.station.test-station"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Test Police Station"].exists)
        XCTAssertTrue(anything(containing: "on foot", in: app).exists)
        XCTAssertTrue(anything(containing: "away in a straight line", in: app).exists,
                      "A station's distance is a straight line and must say so")
        XCTAssertTrue(app.buttons["nearby.directions.test-station"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["nearby.map"].exists)
        XCTAssertTrue(anything(containing: "front counters", in: app).exists)
        XCTAssertTrue(app.staticTexts["nearby.counterNote"].label.contains("call 999"))
    }

    /// Review Focus 4: the 999 line must be on screen when no station is shown, not
    /// only beside one — the person with no signal is the one who most needs it.
    @MainActor
    func testFailedSearchStillSaysFrontCountersAreLimitedAndToCall999() {
        let app = launch(["-kitty.stubNearby", "-kitty.stubNearbySearchFails"])
        app.tabBars.buttons["Nearby"].tap()
        XCTAssertTrue(app.buttons["nearby.retry"].waitForExistence(timeout: 5), "A failed search offers a retry")
        XCTAssertTrue(anything(containing: "could not search", in: app).exists, "The failure says what happened")
        XCTAssertFalse(app.descendants(matching: .any)["nearby.map"].exists, "No map without a result")
        let note = app.staticTexts["nearby.counterNote"]
        XCTAssertTrue(note.exists, "The front-counter note must show when no station is found")
        XCTAssertTrue(note.label.contains("call 999"), "In the UK the note says to call 999")
    }

    @MainActor
    func testRefugesListServicesForTheNationNeverAddresses() {
        let app = launch(["-kitty.stubNearby"])
        app.tabBars.buttons["Nearby"].tap()
        let link = app.buttons["nearby.refuges"]
        app.reveal(link)
        link.tap()

        XCTAssertTrue(app.descendants(matching: .any)["refuges.why"].waitForExistence(timeout: 3),
                      "The reason there are no addresses must be on screen")
        XCTAssertTrue(anything(containing: "Chosen from your location", in: app).exists)
        let england = app.staticTexts["National Domestic Abuse Helpline"]
        app.reveal(england)
        XCTAssertTrue(england.exists)

        app.swipeDown(velocity: .fast)
        app.buttons["refuges.nation"].tap()
        app.buttons["Scotland"].tap()
        let scotland = app.staticTexts["Scotland's Domestic Abuse and Forced Marriage Helpline"]
        app.reveal(scotland)
        XCTAssertTrue(scotland.exists)
        XCTAssertFalse(app.staticTexts["National Domestic Abuse Helpline"].exists, "England's helpline must not be listed for Scotland")
        // Task 8's review: the "chosen from your location" note is seeded from the
        // stub's location, not from whatever is picked afterwards — it must not
        // survive picking a different nation by hand.
        XCTAssertFalse(anything(containing: "Chosen from your location", in: app).exists,
                       "Picking a nation by hand must clear the from-your-location note")
    }

    @MainActor
    func testRefugesAreNotOfferedOutsideTheUK() {
        let app = launch(["-kitty.stubNearby"], locale: "en_US")
        app.tabBars.buttons["Nearby"].tap()
        XCTAssertTrue(app.staticTexts["Written for the UK"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["nearby.refuges"].exists)
    }

    /// Review Focus: the refuge list must name the nation it is filtered to, and must
    /// never show an address, postcode or map pin — refuge addresses are kept
    /// confidential to protect people who fled to one (ADR-0013).
    @MainActor
    func testRefugesScreenNamesTheNationAndNeverShowsAnAddressOrMap() {
        let app = launch(["-kitty.stubNearby"])
        app.tabBars.buttons["Nearby"].tap()
        let link = app.buttons["nearby.refuges"]
        app.reveal(link)
        link.tap()

        XCTAssertTrue(anything(containing: "In England", in: app).waitForExistence(timeout: 3),
                      "The refuge list must name the nation it is filtered to")

        // Wait for a known service to be on screen, so the refuge list has genuinely
        // loaded before the negative checks below run against it — a check made
        // before anything rendered would pass for the wrong reason.
        let england = app.staticTexts["National Domestic Abuse Helpline"]
        app.reveal(england)
        XCTAssertTrue(england.exists)

        // Non-vacuous: a UK postcode dropped into any refuge text (the "why" note,
        // a summary, a name) would match this and fail the test. Proved by
        // temporarily injecting "SW1A 1AA" into refugeNote.text in
        // uk-content.json, confirming this assertion failed, then reverting —
        // see the Task 10 fix report.
        let postcodeShaped = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@",
            "(?i).*\\b[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}\\b.*"
        ))
        XCTAssertEqual(postcodeShaped.count, 0,
                       "No text on the Refuges screen should read like a UK postcode — refuge addresses are confidential")

        // Unlike the postcode check above, this can currently only ever pass —
        // RefugesScreen has no Map view in its source at all — but it still guards
        // against one being added later, which the postcode check would not catch
        // (a map pin is not text). Kept for that reason, not because it can fail today.
        XCTAssertFalse(app.descendants(matching: .any)["nearby.map"].exists, "Refuges must never show a map")
    }

    /// Task 8's review: Women's Aid having no phone line is worth saying on Get help,
    /// where someone might otherwise go looking for a number — but every phoneless
    /// entry in the refuge list is a directory or council route that was never a
    /// phone line, so the same sentence must never appear there.
    @MainActor
    func testNoPhoneLineNoticeShowsOnHelpButNeverOnRefuges() {
        let app = launch(["-kitty.stubNearby"])
        app.tabBars.buttons["Get help"].tap()
        let noPhoneOnHelp = anything(containing: "This service has no phone line.", in: app)
        app.reveal(noPhoneOnHelp)
        XCTAssertTrue(noPhoneOnHelp.exists, "Women's Aid must still show it has no phone line on Get help")

        app.tabBars.buttons["Nearby"].tap()
        let link = app.buttons["nearby.refuges"]
        app.reveal(link)
        link.tap()
        XCTAssertTrue(app.descendants(matching: .any)["refuges.why"].waitForExistence(timeout: 3))
        XCTAssertFalse(anything(containing: "This service has no phone line.", in: app).exists,
                       "No refuge directory shows a no-phone-line notice on the Refuges screen")
    }
}
