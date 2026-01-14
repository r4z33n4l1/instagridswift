//
//  ThumbnailGrid.swift
//  InstaGridswift
//

import SwiftUI

struct ThumbnailGrid: View {
    let images: [PlanImage]
    let aspectRatio: AspectRatio

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: GridConstants.thumbnailSpacing),
            count: GridConstants.columns
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let spacing = GridConstants.thumbnailSpacing
            let columnsCount = CGFloat(GridConstants.columns)
            let totalSpacing = spacing * (columnsCount - 1)
            let itemWidth = (geometry.size.width - totalSpacing) / columnsCount
            let itemHeight = itemWidth / aspectRatio.value

            LazyVGrid(columns: self.columns, spacing: spacing) {
                ForEach(0..<9, id: \.self) { index in
                    thumbnailCell(at: index, width: itemWidth, height: itemHeight)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan preview showing \(min(images.count, 9)) photos")
    }

    @ViewBuilder
    private func thumbnailCell(at index: Int, width: CGFloat, height: CGFloat) -> some View {
        if index < images.count {
            let image = images[index]
            CachedAsyncImage(
                url: image.fileURL,
                cacheKey: image.localPath,
                useThumbnail: true
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
        } else {
            Color.gridItemPlaceholder
                .frame(width: width, height: height)
        }
    }
}

#Preview {
    ThumbnailGrid(images: [], aspectRatio: .feedPortrait)
        .frame(width: 90, height: 112)
}
