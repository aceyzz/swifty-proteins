import SwiftUI

/*
	format custom de layout pour les infos atome
*/
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? .greatestFiniteMagnitude
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let itemWidth = size.width
            let itemHeight = size.height

            if currentRowWidth > 0, currentRowWidth + spacing + itemWidth > availableWidth {
                totalHeight += currentRowHeight + rowSpacing
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRowWidth += (currentRowWidth == 0 ? 0 : spacing) + itemWidth
            currentRowHeight = max(currentRowHeight, itemHeight)
        }

        maxRowWidth = max(maxRowWidth, currentRowWidth)
        totalHeight += currentRowHeight
        return CGSize(width: proposal.width ?? maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let availableWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX, x + spacing + size.width > bounds.minX + availableWidth {
                x = bounds.minX
                y += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            sub.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += (x == bounds.minX ? 0 : spacing) + size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
