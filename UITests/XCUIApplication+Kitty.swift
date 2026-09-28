import XCTest

extension XCUIApplication {

    /// A freshly created app with the base arguments every UI test needs: a pinned
    /// locale, its own Keychain item for trusted contacts (so a developer's real list
    /// is never touched), and whatever else this test needs. Not yet launched, so a
    /// caller that must touch the app first — resetting a system authorization, for
    /// instance — still can before calling `launch()`.
    @MainActor
    static func forTesting(_ switches: [String] = [], locale: String = "en_GB") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", locale, "-AppleLanguages", "(en)", "-kitty.uiTest"] + switches
        return app
    }

    /// Scrolls until the element exists and can actually be tapped. Scrolls down the
    /// page by default; `towardsTop` scrolls back up, for something above the
    /// current scroll position.
    @MainActor
    func reveal(
        _ element: XCUIElement, towardsTop: Bool = false,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        var attempts = 0
        while !isRevealed(element) && attempts < 30 {
            if towardsTop {
                swipeDown(velocity: .slow)
            } else {
                swipeUp(velocity: .slow)
            }
            attempts += 1
        }
        XCTAssertTrue(isRevealed(element), "Could not reach \(element)", file: file, line: line)
    }

    /// Whether the element is hittable and wholly clear of the tab bar, which floats
    /// over the scrolling content. `isHittable` alone is true while only a sliver shows
    /// above the tab bar, and a tap then lands on that sliver: for the nation menu that
    /// is the row's inset, outside the control, so the menu never opens.
    @MainActor
    private func isRevealed(_ element: XCUIElement) -> Bool {
        guard element.exists && element.isHittable else { return false }
        let tabBar = tabBars.firstMatch
        return !tabBar.exists || element.frame.maxY <= tabBar.frame.minY
    }

    /// The first element of any type whose label contains `fragment`, for text a test
    /// knows only part of, or whose element type it should not depend on.
    @MainActor
    func element(containing fragment: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    /// Opens Refuges from the Nearby tab.
    @MainActor
    func openRefuges(file: StaticString = #filePath, line: UInt = #line) {
        tabBars.buttons["Nearby"].tap()
        let link = buttons["nearby.refuges"]
        reveal(link, file: file, line: line)
        link.tap()
    }

    /// Opens the iPhone features from the link at the foot of Get help.
    @MainActor
    func openIPhoneFeatures(file: StaticString = #filePath, line: UInt = #line) {
        tabBars.buttons["Get help"].tap()
        let link = buttons["help.features.link"]
        reveal(link, file: file, line: line)
        link.tap()
    }

    /// Closes a confirmation WITHOUT confirming it. Prefers an explicit Cancel (the
    /// action-sheet presentation); otherwise uses the popover's own dismiss region,
    /// which is what tapping outside a popover hits. Tapping the navigation bar does
    /// not dismiss it.
    @MainActor
    func dismissConfirmation() {
        let cancel = buttons["Cancel"]
        let dismissRegion = otherElements["PopoverDismissRegion"]
        if cancel.exists && cancel.isHittable {
            cancel.tap()
        } else if dismissRegion.exists {
            dismissRegion.tap()
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.05)).tap()
        }
    }

    /// Switches Test Mode on in Settings, then returns to the Alert tab.
    @MainActor
    func turnOnTestMode(file: StaticString = #filePath, line: UInt = #line) {
        tabBars.buttons["Settings"].tap()
        let toggle = switches["settings.testMode"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), file: file, line: line)
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
        XCTAssertEqual(toggle.value as? String, "1", "Test Mode did not switch on", file: file, line: line)
        tabBars.buttons["Alert"].tap()
    }
}
