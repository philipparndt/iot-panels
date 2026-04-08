import SwiftUI

// MARK: - Layout Values

private struct PanelFractionLayoutKey: LayoutValueKey {
    static let defaultValue: Double = 1.0
}

private struct PanelLineBreakLayoutKey: LayoutValueKey {
    static let defaultValue: Bool = false
}

extension View {
    /// Tags a panel view with the row fraction it should occupy. Read by
    /// `PanelFlowLayout` during placement.
    func panelFraction(_ fraction: Double) -> some View {
        layoutValue(key: PanelFractionLayoutKey.self, value: fraction)
    }

    /// Tags a panel view with a forced "start a new row" marker.
    func panelLineBreakBefore(_ shouldBreak: Bool) -> some View {
        layoutValue(key: PanelLineBreakLayoutKey.self, value: shouldBreak)
    }
}

// MARK: - Row Packing Helper

/// Pure-Swift mirror of `PanelFlowLayout`'s row-packing algorithm. Returns
/// the panels grouped into rows in the same order they would be rendered on
/// screen, given the dashboard's horizontal size class. Used by the
/// rearrange mode's row-group view to show the same visual grouping the
/// user sees in normal mode.
func packPanelsIntoRows(_ panels: [DashboardPanel], horizontalSizeClass: UserInterfaceSizeClass?) -> [[DashboardPanel]] {
    var rows: [[DashboardPanel]] = []
    var currentRow: [DashboardPanel] = []
    var currentFraction: Double = 0
    let tolerance = 0.0001

    for panel in panels {
        let fraction = max(0.0, min(1.0, panel.wrappedWidthSlot.fraction(for: horizontalSizeClass)))
        let forceBreak = panel.wrappedLineBreakBefore
        let isFirst = currentRow.isEmpty && rows.isEmpty
        let needsBreak = forceBreak || (currentFraction + fraction > 1.0 + tolerance)

        if needsBreak && !currentRow.isEmpty && !isFirst {
            rows.append(currentRow)
            currentRow = []
            currentFraction = 0
        }
        currentRow.append(panel)
        currentFraction += fraction
    }
    if !currentRow.isEmpty {
        rows.append(currentRow)
    }
    return rows
}

// MARK: - PanelFlowLayout

/// A simple flow layout for dashboard panels: walks subviews in order, packs
/// each into the current row by accumulating its declared row fraction, and
/// starts a new row whenever the next subview would overflow or carries a
/// forced line-break marker.
///
/// Sort order is authoritative — packing never reorders subviews.
struct PanelFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 16
    var verticalSpacing: CGFloat = 16

    struct Cache {
        var rows: [[Int]] = []      // indices into subviews
        var rowHeights: [CGFloat] = []
        var totalHeight: CGFloat = 0
        var containerWidth: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 0
        compute(into: &cache, subviews: subviews, containerWidth: width)
        return CGSize(width: width, height: cache.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        if cache.rows.isEmpty || cache.containerWidth != bounds.width {
            compute(into: &cache, subviews: subviews, containerWidth: bounds.width)
        }

        var y = bounds.minY
        for (rowIdx, row) in cache.rows.enumerated() {
            let rowHeight = cache.rowHeights[rowIdx]

            // First pass: compute each panel's target width based on its fraction.
            // Spacing reduces the effective row width by (count - 1) * spacing.
            let count = row.count
            let totalSpacing = CGFloat(max(count - 1, 0)) * horizontalSpacing
            let availableWidth = max(bounds.width - totalSpacing, 0)

            var x = bounds.minX
            for index in row {
                let subview = subviews[index]
                let fraction = subview[PanelFractionLayoutKey.self]
                let panelWidth = availableWidth * CGFloat(fraction)
                let proposal = ProposedViewSize(width: panelWidth, height: rowHeight)
                subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: proposal
                )
                x += panelWidth + horizontalSpacing
            }

            y += rowHeight
            if rowIdx < cache.rows.count - 1 {
                y += verticalSpacing
            }
        }
    }

    // MARK: - Packing

    private func compute(into cache: inout Cache, subviews: Subviews, containerWidth: CGFloat) {
        cache = Cache()
        cache.containerWidth = containerWidth

        var currentRow: [Int] = []
        var currentRowFraction: Double = 0
        // Tiny tolerance to absorb floating-point fuzz when fractions sum to 1.0
        let tolerance = 0.0001

        for index in subviews.indices {
            let subview = subviews[index]
            let fraction = max(0.0, min(1.0, subview[PanelFractionLayoutKey.self]))
            let forceBreak = subview[PanelLineBreakLayoutKey.self]

            let needsBreak = forceBreak || (currentRowFraction + fraction > 1.0 + tolerance)
            // Don't break for the very first panel even if it has lineBreakBefore.
            let isFirst = currentRow.isEmpty && cache.rows.isEmpty

            if needsBreak && !currentRow.isEmpty && !isFirst {
                cache.rows.append(currentRow)
                currentRow = []
                currentRowFraction = 0
            } else if needsBreak && currentRow.isEmpty && isFirst {
                // First panel with a break flag — ignore the break.
            }

            currentRow.append(index)
            currentRowFraction += fraction
        }

        if !currentRow.isEmpty {
            cache.rows.append(currentRow)
        }

        // Compute row heights from each subview's natural height at its
        // resolved width.
        var totalHeight: CGFloat = 0
        for row in cache.rows {
            let count = row.count
            let totalSpacing = CGFloat(max(count - 1, 0)) * horizontalSpacing
            let availableWidth = max(containerWidth - totalSpacing, 0)

            var rowHeight: CGFloat = 0
            for index in row {
                let subview = subviews[index]
                let fraction = max(0.0, min(1.0, subview[PanelFractionLayoutKey.self]))
                let panelWidth = availableWidth * CGFloat(fraction)
                let size = subview.sizeThatFits(ProposedViewSize(width: panelWidth, height: nil))
                rowHeight = max(rowHeight, size.height)
            }
            cache.rowHeights.append(rowHeight)
            totalHeight += rowHeight
        }
        if cache.rows.count > 1 {
            totalHeight += CGFloat(cache.rows.count - 1) * verticalSpacing
        }
        cache.totalHeight = totalHeight
    }
}
