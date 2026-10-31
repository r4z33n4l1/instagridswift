//
//  ImagePreviewView.swift
//  InstaGridswift
//

import SwiftUI

struct ImagePreviewView: View {
    let image: PlanImage
    let aspectRatio: AspectRatio

    // Computed preview size based on aspect ratio
    private var previewSize: CGSize {
        let maxWidth: CGFloat = 280
        let maxHeight: CGFloat = 380

        let targetRatio = aspectRatio.value

        // Calculate size that fits within bounds while maintaining aspect ratio
        let widthFromHeight = maxHeight * targetRatio
        let heightFromWidth = maxWidth / targetRatio

        if widthFromHeight <= maxWidth {
            return CGSize(width: widthFromHeight, height: maxHeight)
        } else {
            return CGSize(width: maxWidth, height: heightFromWidth)
        }
    }

    var body: some View {
        CachedAsyncImage(
            url: image.fileURL,
            cacheKey: image.localPath,
            useThumbnail: false // Full quality for preview
        )
        .aspectRatio(contentMode: .fill)
        .frame(width: previewSize.width, height: previewSize.height)
        .modifier(CropAppliedModifier(
            cropSettings: image.cropSettings(for: aspectRatio),
            frameSize: previewSize,
            imageWidth: image.width,
            imageHeight: image.height
        ))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ImagePreviewView(
        image: PlanImage(localPath: "", width: 1080, height: 1350, order: 0),
        aspectRatio: .feedPortrait
    )
}
