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
        let app = XCUIApplication.forTesting((resetNation ? ["-kitty.resetNation"] : []) + switches)
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
        // Proves the filter is actually heavy, not just heavy in name: without this,
        // the search below would leave nothing on its own, and the test would pass
        // unchanged even if choosing the nation or the chip had silently done nothing.
        XCTAssertTrue(chip.isSelected, "Work must say it is selected")
        let summaryBeforeSearch = element("filter.summary", in: app)
        app.reveal(summaryBeforeSearch)
        XCTAssertTrue(
            summaryBeforeSearch.label.contains("Northern Ireland") && summaryBeforeSearch.label.contains("Work"),
            "The nation and the topic must both have applied: \(summaryBeforeSearch.label)"
        )
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
        let summary = element("filter.summary", in: app)
        app.reveal(summary, towardsTop: true)
        XCTAssertTrue(summary.label.contains("stalking"), summary.label)
        // Checked here, back at the top, rather than right after revealing Victim
        // Support: the pack lists that service last, so scrolling down to it would
        // carry National Domestic Abuse Helpline out of the lazy List regardless of
        // whether the search filtered anything at all.
        XCTAssertFalse(
            app.staticTexts["National Domestic Abuse Helpline"].exists,
            "National Domestic Abuse Helpline is not tagged Stalking & harassment"
        )
    }

    /// Review Focus 4. List rows are read top to bottom, so vertical order is reading
    /// order. Shared by Get help and Learn, which must both read the same way: the
    /// nation menu, then the chips, then the summary and Clear, then the results.
    @MainActor
    private func assertFilterControlsPrecedeResults(
        onTab tab: String, firstResult: (XCUIApplication) -> XCUIElement,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let app = launch()
        app.tabBars.buttons[tab].tap()
        let chip = app.buttons["filter.topic.domesticAbuse"]
        app.reveal(chip, file: file, line: line)
        let menu = app.buttons["filter.nation"]
        XCTAssertLessThan(menu.frame.minY, chip.frame.minY, "The nation menu comes before the chips", file: file, line: line)
        chip.tap()
        XCTAssertTrue(chip.isSelected, "A chosen chip must say it is selected", file: file, line: line)
        XCTAssertFalse(
            app.buttons["filter.topic.sexualViolence"].isSelected, "Tapping one chip must not toggle its neighbours",
            file: file, line: line
        )

        let summary = element("filter.summary", in: app)
        let clear = app.buttons["filter.clear"]
        let first = firstResult(app)
        app.reveal(first, file: file, line: line)
        XCTAssertTrue(summary.exists && clear.exists, "The summary and Clear must sit just above the first result", file: file, line: line)
        XCTAssertLessThan(chip.frame.minY, summary.frame.minY, "The chips come before the summary", file: file, line: line)
        XCTAssertLessThanOrEqual(summary.frame.maxY, first.frame.minY, "The summary comes before the results", file: file, line: line)
        XCTAssertLessThan(clear.frame.minY, first.frame.minY, "Clear comes before the results", file: file, line: line)
        clear.tap()
        XCTAssertFalse(chip.isSelected, "Clear must deselect the topics", file: file, line: line)
    }

    @MainActor
    func testTheSummaryAndClearComeBeforeTheResults() {
        assertFilterControlsPrecedeResults(onTab: "Get help") { $0.staticTexts["National Domestic Abuse Helpline"] }
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

    // MARK: - Learn

    @MainActor
    func testSearchingStalkingOnLearnFindsTheTopic() {
        let app = launch()
        app.tabBars.buttons["Learn"].tap()
        search("stalking", in: app)
        XCTAssertTrue(app.buttons["learn.rights.stalking-and-harassment"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["learn.rights.housing-help"].exists, "A topic with no stalking in it must not match")
    }

    @MainActor
    func testRightsForOtherNationsAreCollapsedNotRemoved() {
        let app = launch()
        app.tabBars.buttons["Learn"].tap()
        choose("Scotland", in: app)
        let topic = app.buttons["learn.rights.what-counts-as-domestic-abuse"]
        app.reveal(topic)
        topic.tap()
        XCTAssertTrue(anything(containing: "Applies in Scotland", in: app).waitForExistence(timeout: 3))
        XCTAssertFalse(anything(containing: "Applies in England and Wales", in: app).exists,
                       "Other nations' points start collapsed")
        // The identifier, not the English label: proves it lands on the disclosure
        // row itself, not on every row it expands to reveal.
        let elsewhere = app.buttons["rights.elsewhere"]
        app.reveal(elsewhere)
        elsewhere.tap()
        let englandAndWales = anything(containing: "Applies in England and Wales", in: app)
        app.reveal(englandAndWales)
        XCTAssertTrue(englandAndWales.exists, "Other nations' points are hidden until opened, never removed")
    }

    /// Review Focus 4, on Learn: the same reading order required on Get help must hold
    /// here too — see `assertFilterControlsPrecedeResults`.
    @MainActor
    func testTheSummaryAndClearComeBeforeTheResultsOnLearn() {
        assertFilterControlsPrecedeResults(onTab: "Learn") { $0.buttons["learn.rights.what-counts-as-domestic-abuse"] }
    }

    /// Review Focus 3: features ignore topics, so a filter can empty the rights section
    /// while features are still listed. The rights section must say so, with Clear,
    /// and Clear must actually restore the rights list.
    @MainActor
    func testLearnSaysWhenNoRightsTopicMatchesEvenWithFeaturesListed() {
        let app = launch()
        app.tabBars.buttons["Learn"].tap()
        search("check in", in: app)
        XCTAssertTrue(anything(containing: "No rights topics match", in: app).waitForExistence(timeout: 3))
        let clear = app.buttons["filter.noMatches.clear"]
        XCTAssertTrue(clear.exists)
        let feature = app.buttons["learn.feature.check-in"]
        app.reveal(feature)
        XCTAssertTrue(feature.exists)

        app.reveal(clear, towardsTop: true)
        clear.tap()
        let topic = app.buttons["learn.rights.what-counts-as-domestic-abuse"]
        app.reveal(topic, towardsTop: true)
        XCTAssertTrue(topic.exists, "Clear must bring the rights list back")
        XCTAssertFalse(anything(containing: "No rights topics match", in: app).exists)
    }

    @MainActor
    func testIPhoneFeaturesCanBeSearched() {
        let app = launch()
        app.tabBars.buttons["Get help"].tap()
        let link = app.buttons["help.features.link"]
        app.reveal(link)
        link.tap()
        search("check in", in: app)
        XCTAssertTrue(app.buttons["learn.feature.check-in"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["learn.feature.emergency-sos"].exists)
        XCTAssertTrue(element("filter.summary", in: app).exists, "An active search is stated")
    }

    @MainActor
    func testIPhoneFeaturesSayWhenNothingMatchesAndClearRestoresTheList() {
        let app = launch()
        app.tabBars.buttons["Get help"].tap()
        let link = app.buttons["help.features.link"]
        app.reveal(link)
        link.tap()
        search("zzqx", in: app)
        let clear = app.buttons["filter.noMatches.clear"]
        app.reveal(clear)
        XCTAssertTrue(element("filter.noMatches", in: app).exists, "Nothing matching must be said, never shown as an empty list")
        clear.tap()
        let feature = app.buttons["learn.feature.emergency-sos"]
        app.reveal(feature)
        XCTAssertTrue(feature.exists, "Clear must bring the feature list back")
        XCTAssertFalse(element("filter.noMatches", in: app).exists)
    }
}
