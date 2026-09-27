import XCTest

extension XCUIApplication {

    /// Scrolls until the element exists and can actually be tapped. Scrolls down the
    /// page by default; `towardsTop` scrolls back up, for something above the
    /// current scroll position.
    @MainActor
    func reveal(
        _ element: XCUIElement, towardsTop: Bool = false,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 30 {
            if towardsTop {
                swipeDown(velocity: .slow)
            } else {
                swipeUp(velocity: .slow)
            }
            attempts += 1
        }
        XCTAssertTrue(element.isHittable, "Could not reach \(element)", file: file, line: line)
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
}
