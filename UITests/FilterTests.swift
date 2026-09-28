import XCTest

/// Filtering Get help, Learn and Refuges end to end: the nation, the topic chips and
/// search. `-kitty.resetNation` starts each test at All of the UK. The relaunch test
/// leaves it off on purpose.
//
// Swift 6 strict mode: see HelpCallTests for why the class is nonisolated and the
// methods are @MainActor.
final class FilterTests: XCTestCase {

    @MainActor
    private func launch(_ switches: [String] = [], resetNation: Bool = true) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "en_GB", "-AppleLanguages", "(en)", "-kitty.uiTest"]
            + (resetNation ? ["-kitty.resetNation"] : []) + switches
        app.launch()
        return app
    }

    @MainActor
    private func anything(containing fragment: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func choose(_ nation: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let menu = app.buttons["filter.nation"]
        app.reveal(menu, file: file, line: line)
        menu.tap()
        let item = app.buttons[nation]
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(nation) is not in the nation menu", file: file, line: line)
        item.tap()
    }

    /// Types into the always-visible search field and submits, which also puts the
    /// keyboard away so the results can be reached.
    @MainActor
    private func search(_ text: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "The search field must always be visible", file: file, line: line)
        field.tap()
        field.typeText(text + "\n")
    }

    // MARK: - Get help

    /// The spec's hardest case: Test Mode on, a nation, a chip, and a search that matches
    /// nothing. The model test proves every combination; this proves the screen.
    @MainActor
    func test999AndTheTestModeBannerAreNeverFiltered() {
        let app = launch()
        app.turnOnTestMode()
        app.tabBars.buttons["Get help"].tap()
        choose("Northern Ireland", in: app)
        let chip = app.buttons["filter.topic.work"]
        app.reveal(chip)
        chip.tap()
        search("zzqx", in: app)
        XCTAssertTrue(app.buttons["filter.noMatches.clear"].waitForExistence(timeout: 3), "The filter must leave nothing below 999")

        let banner = element("testMode.banner", in: app)
        app.reveal(banner, towardsTop: true)
        XCTAssertTrue(banner.exists, "The Test Mode banner must never be filtered")
        let firstRoute = anything(containing: "Call 999 or 112", in: app)
        app.reveal(firstRoute)
        XCTAssertTrue(firstRoute.exists, "The 999 routes must never be filtered")
        let lastRoute = anything(containing: "Relay UK", in: app)
        app.reveal(lastRoute)
        XCTAssertTrue(lastRoute.exists, "Every 999 route must stay, not only the first")
    }

    @MainActor
    func testNothingMatchesSaysSoAndClearRestoresTheList() {
        let app = launch()
        app.tabBars.buttons["Get help"].tap()
        search("zzqx", in: app)
        let clear = app.buttons["filter.noMatches.clear"]
        app.reveal(clear)
        XCTAssertTrue(element("filter.noMatches", in: app).exists, "Nothing matching must be said, never shown as an empty list")
        clear.tap()
        let first = app.staticTexts["National Domestic Abuse Helpline"]
        app.reveal(first)
        XCTAssertTrue(first.exists, "Clear must bring the list back")
        XCTAssertFalse(element("filter.noMatches", in: app).exists)
    }

    @MainActor
    func testScotlandShowsItsOwnHelplineAndHidesEnglands() {
        let app = launch()
        app.tabBars.buttons["Get help"].tap()
        choose("Scotland", in: app)
        let summary = element("filter.summary", in: app)
        app.reveal(summary)
        XCTAssertTrue(summary.label.contains("Showing Scotland"), summary.label)

        let scotland = app.staticTexts["Scotland's Domestic Abuse and Forced Marriage Helpline"]
        app.reveal(scotland)
        XCTAssertTrue(scotland.exists)
        // Unfiltered, both are listed directly above Scotland's line, so they would be
        // on screen now if they were shown.
        XCTAssertFalse(app.staticTexts["National Domestic Abuse Helpline"].exists, "England's helpline must not be listed for Scotland")
        XCTAssertFalse(app.staticTexts["Live Fear Free"].exists, "Wales's helpline must not be listed for Scotland")
    }

    @MainActor
    func testSearchingStalkingFindsTheServicesForIt() {
        let app = launch()
        app.tabBars.buttons["Get help"].tap()
        search("stalking", in: app)
        let victimSupport = app.staticTexts["Victim Support Supportline"]
        app.reveal(victimSupport)
        XCTAssertTrue(victimSupport.exists, "Victim Support is tagged Stalking & harassment")
        XCTAssertFalse(app.staticTexts["National Domestic Abuse Helpline"].exists)
        let summary = element("filter.summary", in: app)
        app.reveal(summary, towardsTop: true)
        XCTAssertTrue(summary.label.contains("stalking"), summary.label)
    }

    /// Review Focus 4. List rows are read top to bottom, so vertical order is reading order.
    @MainActor
    func testTheSummaryAndClearComeBeforeTheResults() {
        let app = launch()
        app.tabBars.buttons["Get help"].tap()
        let chip = app.buttons["filter.topic.domesticAbuse"]
        app.reveal(chip)
        let menu = app.buttons["filter.nation"]
        XCTAssertLessThan(menu.frame.minY, chip.frame.minY, "The nation menu comes before the chips")
        chip.tap()
        XCTAssertTrue(chip.isSelected, "A chosen chip must say it is selected")
        XCTAssertFalse(app.buttons["filter.topic.sexualViolence"].isSelected, "Tapping one chip must not toggle its neighbours")

        let summary = element("filter.summary", in: app)
        let clear = app.buttons["filter.clear"]
        let first = app.staticTexts["National Domestic Abuse Helpline"]
        app.reveal(first)
        XCTAssertTrue(summary.exists && clear.exists, "The summary and Clear must sit just above the first result")
        XCTAssertLessThan(chip.frame.minY, summary.frame.minY, "The chips come before the summary")
        XCTAssertLessThanOrEqual(summary.frame.maxY, first.frame.minY, "The summary comes before the results")
        XCTAssertLessThan(clear.frame.minY, first.frame.minY, "Clear comes before the results")
        clear.tap()
        XCTAssertFalse(chip.isSelected, "Clear must deselect the topics")
    }

    @MainActor
    func testTheNationSurvivesARelaunch() {
        var app = launch()
        app.tabBars.buttons["Get help"].tap()
        choose("Wales", in: app)
        app.terminate()

        app = launch(resetNation: false)
        app.tabBars.buttons["Get help"].tap()
        let summary = element("filter.summary", in: app)
        app.reveal(summary)
        XCTAssertTrue(summary.label.contains("Showing Wales"), "The chosen nation must be remembered: \(summary.label)")
    }

    @MainActor
    func testChipsWrapAndCanBeTappedAtTheLargestTextSize() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.tabBars.buttons["Get help"].tap()
        let window = app.windows.firstMatch.frame
        for id in ["domesticAbuse", "sexualViolence", "stalkingAndHarassment", "onlineAbuse",
                   "forcedMarriageAndFGM", "housingAndMoney", "work", "reportingAndVictimsRights"] {
            let chip = app.buttons["filter.topic.\(id)"]
            app.reveal(chip)
            XCTAssertGreaterThanOrEqual(chip.frame.height, 44, "\(id) is smaller than the minimum tap target")
            XCTAssertGreaterThanOrEqual(chip.frame.width, 44, "\(id) is narrower than the minimum tap target")
            XCTAssertGreaterThanOrEqual(chip.frame.minX, window.minX, "\(id) starts off screen")
            XCTAssertLessThanOrEqual(chip.frame.maxX, window.maxX, "\(id) runs off screen instead of wrapping")
            chip.tap()
            XCTAssertTrue(chip.isSelected, "\(id) must say it is selected")
            chip.tap()
            XCTAssertFalse(chip.isSelected, "\(id) must say it is no longer selected")
        }
    }
}
