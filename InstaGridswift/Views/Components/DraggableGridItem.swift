//
//  DraggableGridItem.swift
//  InstaGridswift
//

import SwiftUI

struct DraggableGridItem: View {
    let image: PlanImage
    let size: CGSize
    let isSelected: Bool
    let editMode: Bool
    let isDragging: Bool
    let isDropTarget: Bool
    let aspectRatio: AspectRatio

    // Overlay state
    @Binding var showingOverlayForID: UUID?

    let onTap: () -> Void
    let onDelete: () -> Void
    let onHide: () -> Void
    let onEditCrop: () -> Void
    let onDragStarted: (CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    private var isShowingOverlay: Bool {
        showingOverlayForID == image.id
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content wrapped in gesture button (only in normal mode)
            if editMode {
                // Edit mode - simple tap for selection
                editModeContent
            } else if isShowingOverlay {
                // Overlay showing - no gestures needed
                normalContent
            } else {
                // Normal mode - use ScrollViewGestureButton for gestures
                ScrollViewGestureButton(
                    longPressDuration: 0.5,
                    onLongPress: {
                        withAnimation(.snappySpring) {
                            showingOverlayForID = image.id
                        }
                        HapticService.notification(.success)
                    },
                    onDragStart: { location in
                        HapticService.impact(.medium)
                        onDragStarted(location)
                    },
                    onDragChange: { translation in
                        onDragChanged(translation)
                    },
                    onDragEnd: {
                        onDragEnded()
                    }
                ) {
                    normalContent
                }
            }

            // Edit mode overlays
            if editMode {
                if isSelected {
                    selectionOverlay
                }
                deleteButton
            }

            // Action overlay (when long pressed in normal mode)
            if isShowingOverlay && !editMode {
                ImageActionOverlay(
                    onHide: {
                        withAnimation(.snappySpring) {
                            showingOverlayForID = nil
                        }
                        onHide()
                    },
                    onEdit: {
                        withAnimation(.snappySpring) {
                            showingOverlayForID = nil
                        }
                        onEditCrop()
                    },
                    onDismiss: {
                        withAnimation(.snappySpring) {
                            showingOverlayForID = nil
                        }
                    }
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Rectangle())
        .overlay {
            if isDropTarget && !isDragging {
                ZStack {
                    // Subtle fill to indicate drop zone
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primaryAccent.opacity(0.15))
                    // Prominent border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primaryAccent, lineWidth: 4)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.snappySpring, value: isDropTarget)
        .opacity(isDragging ? 0.3 : 1.0)
        .zIndex(isShowingOverlay ? 100 : 0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photo \(image.order + 1)")
        .accessibilityHint(editMode ? "Double tap to select" : "Long press for options")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // Normal content (image with crop applied, properly clipped)
    @ViewBuilder
    private var normalContent: some View {
        // Container that clips AFTER all crop transforms
        Rectangle()
            .fill(Color.clear)
            .frame(width: size.width, height: size.height)
            .overlay {
                imageContent
                    .frame(width: size.width, height: size.height)
                    .modifier(CropAppliedModifier(
                        cropSettings: image.cropSettings(for: aspectRatio),
                        frameSize: size,
                        imageWidth: image.width,
                        imageHeight: image.height
                    ))
            }
            .clipShape(Rectangle()) // Clips AFTER crop transforms
            .contentShape(Rectangle()) // Ensures hit testing matches visual bounds
    }

    // Edit mode content with tap gesture
    @ViewBuilder
    private var editModeContent: some View {
        normalContent
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
                HapticService.selection()
            }
    }

    @ViewBuilder
    private var imageContent: some View {
        CachedAsyncImage(
            url: image.fileURL,
            cacheKey: image.localPath,
            useThumbnail: true
        )
        .aspectRatio(contentMode: .fill)
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        ZStack {
            Color.selectionTint

            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button {
            HapticService.impact(.medium)
            onDelete()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.6))
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
        .padding(4)
        .accessibilityLabel("Delete photo")
        .accessibilityHint("Double tap to remove this photo")
    }
}

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

#Preview {
    DraggableGridItem(
        image: PlanImage(localPath: "", width: 100, height: 100, order: 0),
        size: CGSize(width: 120, height: 150),
        isSelected: false,
        editMode: false,
        isDragging: false,
        isDropTarget: false,
        aspectRatio: .feedPortrait,
        showingOverlayForID: .constant(nil),
        onTap: {},
        onDelete: {},
        onHide: {},
        onEditCrop: {},
        onDragStarted: { _ in },
        onDragChanged: { _ in },
        onDragEnded: {}
    )
}
