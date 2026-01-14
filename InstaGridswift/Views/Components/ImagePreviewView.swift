//
//  ImagePreviewView.swift
//  InstaGridswift
//

import SwiftUI

struct ImagePreviewView: View {
    let image: PlanImage

    private var imageAspectRatio: CGFloat {
        guard image.height > 0 else { return 1.0 }
        return CGFloat(image.width) / CGFloat(image.height)
    }

    var body: some View {
        CachedAsyncImage(
            url: image.fileURL,
            cacheKey: image.localPath,
            useThumbnail: false // Full quality for preview
        )
        .aspectRatio(imageAspectRatio, contentMode: .fit)
        .frame(maxWidth: 300, maxHeight: 400)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ImagePreviewView(
        image: PlanImage(localPath: "", width: 1080, height: 1350, order: 0)
    )
}
