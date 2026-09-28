import SwiftUI
import Testing

@testable import SafetyUI

/// `Design.adaptiveStack` decides, from the Dynamic Type size alone, whether a "label and
/// value" pair should sit side by side or stack vertically. `AnyLayout` cannot be
/// inspected once built — `LayoutSubviews` has no public initializer, so there is no way
/// to render it in a test — which is exactly why the decision itself is pulled out into
/// `Design.stacksVertically(at:)`: a plain `Bool` that is tested without rendering
/// anything, the same reasoning as `ChipFlowLayout.rows` and `ServiceRow.shouldShowNoPhoneLine`.
@Suite("Adaptive stack")
struct DesignSystemTests {

    @Test("Stacks vertically at every accessibility size")
    func verticalAtAccessibilitySizes() {
        for size in DynamicTypeSize.allCases where size.isAccessibilitySize {
            #expect(Design.stacksVertically(at: size), "\(size) should stack vertically")
        }
    }

    @Test("Sits side by side at every standard size")
    func horizontalAtStandardSizes() {
        for size in DynamicTypeSize.allCases where !size.isAccessibilitySize {
            #expect(!Design.stacksVertically(at: size), "\(size) should sit side by side")
        }
    }

    @Test("Every Dynamic Type size is covered, in both directions")
    func everySizeCovered() {
        // Guards against `DynamicTypeSize` gaining a case neither test above would
        // catch: every case is either accessibility or standard, never neither.
        #expect(!DynamicTypeSize.allCases.isEmpty)
        for size in DynamicTypeSize.allCases {
            #expect(Design.stacksVertically(at: size) == size.isAccessibilitySize)
        }
    }
}
