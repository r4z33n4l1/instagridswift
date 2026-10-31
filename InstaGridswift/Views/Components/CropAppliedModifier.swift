//
//  CropAppliedModifier.swift
//  InstaGridswift
//

import SwiftUI

// Modifier to apply crop settings to image display
struct CropAppliedModifier: ViewModifier {
    let cropSettings: CropSettings
    let frameSize: CGSize
    let imageWidth: Int
    let imageHeight: Int

    // Image aspect ratio from original dimensions
    private var imageAspectRatio: CGFloat {
        guard imageHeight > 0 else { return 1.0 }
        return CGFloat(imageWidth) / CGFloat(imageHeight)
    }

    // Calculate displayed image size when using .fill
    private func displayedImageSize() -> CGSize {
        guard frameSize.width > 0 && frameSize.height > 0 else {
            return frameSize
        }
        let frameRatio = frameSize.width / frameSize.height

        if imageAspectRatio > frameRatio {
            // Image is wider than frame - height matches, width overflows
            let height = frameSize.height
            let width = height * imageAspectRatio
            return CGSize(width: width, height: height)
        } else {
            // Image is taller than frame - width matches, height overflows
            let width = frameSize.width
            let height = width / imageAspectRatio
            return CGSize(width: width, height: height)
        }
    }

    // Calculate max offset based on image overflow
    private func maxOffset(scale: CGFloat) -> CGSize {
        let displayedSize = displayedImageSize()
        let scaledWidth = displayedSize.width * scale
        let scaledHeight = displayedSize.height * scale

        let extraWidth = max(0, (scaledWidth - frameSize.width) / 2)
        let extraHeight = max(0, (scaledHeight - frameSize.height) / 2)

        return CGSize(width: extraWidth, height: extraHeight)
    }

    func body(content: Content) -> some View {
        let maxOff = maxOffset(scale: cropSettings.scale)
        content
            .scaleEffect(cropSettings.scale)
            .offset(
                x: cropSettings.offsetX * maxOff.width,
                y: cropSettings.offsetY * maxOff.height
            )
    }
}
