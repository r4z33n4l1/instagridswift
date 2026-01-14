//
//  AnimatedReorderableGrid.swift
//  InstaGridswift
//

import SwiftUI

struct AnimatedReorderableGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let itemSize: CGSize
    let draggedItemID: Item.ID?
    let draggedSourceIndex: Int?
    let proposedDropIndex: Int?
    @ViewBuilder let content: (Item, Int) -> Content

    var body: some View {
        let gridWidth = calculateGridWidth()
        let gridHeight = calculateGridHeight()

        // Simplified logging
        let dragID = draggedItemID.map { "\($0)".prefix(4) } ?? "nil"
        let _ = print("🔲 Grid: \(items.count) items, drag:\(dragID), src:\(draggedSourceIndex ?? -1), drop:\(proposedDropIndex ?? -1)")

        ZStack(alignment: .topLeading) {
            // Invisible spacer to establish the grid size
            Color.clear
                .frame(width: gridWidth, height: gridHeight)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let position = calculatePosition(for: index)
                let isDragged = item.id == draggedItemID

                content(item, index)
                    .frame(width: itemSize.width, height: itemSize.height)
                    .offset(x: position.x, y: position.y)
                    .opacity(isDragged ? 0.3 : 1.0)
                    .zIndex(isDragged ? -1 : 0)
                    .animation(.gapSpring, value: position.x)
                    .animation(.gapSpring, value: position.y)
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        .padding(spacing)
    }

    private func calculateGridWidth() -> CGFloat {
        CGFloat(columns) * itemSize.width + CGFloat(columns - 1) * spacing
    }

    private func calculateGridHeight() -> CGFloat {
        guard !items.isEmpty else { return 0 }
        let rows = (items.count + columns - 1) / columns
        return CGFloat(rows) * itemSize.height + CGFloat(rows - 1) * spacing
    }

    private func calculatePosition(for index: Int) -> CGPoint {
        var adjustedIndex = index

        // Apply gap shift if we're dragging
        if let sourceIndex = draggedSourceIndex,
           let dropIndex = proposedDropIndex,
           sourceIndex != dropIndex {

            let itemID = items[index].id
            let isDraggedItem = itemID == draggedItemID

            if !isDraggedItem {
                // Calculate visual shift for non-dragged items
                if sourceIndex < dropIndex {
                    // Dragging forward: items between source and drop shift backward
                    if index > sourceIndex && index <= dropIndex {
                        adjustedIndex = index - 1
                    }
                } else {
                    // Dragging backward: items between drop and source shift forward
                    if index >= dropIndex && index < sourceIndex {
                        adjustedIndex = index + 1
                    }
                }
            }
        }

        let row = adjustedIndex / columns
        let col = adjustedIndex % columns

        return CGPoint(
            x: CGFloat(col) * (itemSize.width + spacing),
            y: CGFloat(row) * (itemSize.height + spacing)
        )
    }
}

// Extension for gap animation
extension Animation {
    static let gapSpring = Animation.spring(response: 0.3, dampingFraction: 0.75)
    static let liftSpring = Animation.spring(response: 0.25, dampingFraction: 0.65)
}
