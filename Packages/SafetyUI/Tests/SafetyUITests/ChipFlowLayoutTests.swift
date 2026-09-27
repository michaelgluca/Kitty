import Foundation
import Testing

@testable import SafetyUI

/// The chip rows, decided without rendering. At the largest text sizes a chip may be as
/// wide as the screen; it must get a row of its own and wrap its text, never be squeezed
/// or pushed off the edge.
@Suite("Chip layout")
struct ChipFlowLayoutTests {

    private func rows(_ widths: [CGFloat], in width: CGFloat) -> [[Int]] {
        ChipFlowLayout.rows(for: widths.map { CGSize(width: $0, height: 44) }, width: width, spacing: 8)
    }

    @Test("Chips share a row while they fit, spacing included")
    func fit() { #expect(rows([100, 100], in: 208) == [[0, 1]]) }

    @Test("A chip that does not fit starts a new row")
    func wraps() { #expect(rows([100, 100, 100], in: 250) == [[0, 1], [2]]) }

    @Test("A chip wider than the row gets a row of its own")
    func wide() { #expect(rows([50, 400, 50], in: 300) == [[0], [1], [2]]) }

    @Test("At the largest text sizes, each chip takes its own row")
    func accessibilitySizes() { #expect(rows([320, 320, 320], in: 320) == [[0], [1], [2]]) }

    @Test("No chips, no rows")
    func empty() { #expect(rows([], in: 300).isEmpty) }
}
