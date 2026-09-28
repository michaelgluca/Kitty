import SwiftUI

/// Lays chips out left to right and wraps them onto new rows.
///
/// Each chip is offered the full width, so at the largest text sizes a long chip takes a
/// row of its own and wraps its words instead of being squeezed, truncated or pushed off
/// screen.
struct ChipFlowLayout: Layout {

    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let sizes = measure(subviews, width: width)
        let rows = Self.rows(for: sizes, width: width, spacing: spacing)
        let height = rows.map { Self.height(of: $0, in: sizes) }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let rowWidths = rows.map { row in
            row.map { sizes[$0].width }.reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0))
        }
        let usedWidth = rowWidths.max() ?? 0
        return CGSize(width: min(usedWidth, proposal.width ?? usedWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = measure(subviews, width: bounds.width)
        var y = bounds.minY
        for row in Self.rows(for: sizes, width: bounds.width, spacing: spacing) {
            var x = bounds.minX
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sizes[index]))
                x += sizes[index].width + spacing
            }
            y += Self.height(of: row, in: sizes) + spacing
        }
    }

    private static func height(of row: [Int], in sizes: [CGSize]) -> CGFloat {
        row.map { sizes[$0].height }.max() ?? 0
    }

    private func measure(_ subviews: Subviews, width: CGFloat) -> [CGSize] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
    }

    /// Which chips go on each row, by index. Pure, so the wrapping rule is tested without
    /// rendering.
    static func rows(for sizes: [CGSize], width: CGFloat, spacing: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var x: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            let needed = current.isEmpty ? size.width : x + spacing + size.width
            if !current.isEmpty && needed > width {
                rows.append(current)
                current = [index]
                x = size.width
            } else {
                current.append(index)
                x = needed
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}
