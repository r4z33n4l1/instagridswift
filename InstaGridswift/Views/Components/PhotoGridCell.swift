//
//  PhotoGridCell.swift
//  InstaGridswift
//

import SwiftUI
import UIKit

struct PhotoGridCell: View {
    let image: PlanImage
    let size: CGSize
    let isSelected: Bool
    let editMode: Bool
    let isDragging: Bool  // Is THIS cell being dragged
    let isAnyDragging: Bool  // Is ANY cell being dragged
    let aspectRatio: AspectRatio
    let index: Int

    let onTap: () -> Void
    let onDelete: () -> Void
    let onHide: () -> Void
    let onEditCrop: () -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isLifted: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if editMode {
                editModeContent
            } else {
                normalContent
            }

            // Edit mode overlays
            if editMode {
                if isSelected {
                    selectionOverlay
                }
                deleteButton
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Rectangle())
        .offset(dragOffset)
        .scaleEffect(isLifted ? 1.05 : 1.0)
        .opacity(isDragging && !isLifted ? 0.3 : 1.0)
        .shadow(
            color: .black.opacity(isLifted ? 0.3 : 0),
            radius: isLifted ? 10 : 0,
            x: 0,
            y: isLifted ? 5 : 0
        )
        .zIndex(isLifted ? 100 : 0)
        .animation(.easeOut(duration: 0.15), value: isLifted)
        .animation(.easeOut(duration: 0.15), value: dragOffset)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photo \(image.order + 1)")
        .accessibilityHint(editMode ? "Double tap to select" : "Long press for options")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // Normal content with smooth drag support and native context menu
    @ViewBuilder
    private var normalContent: some View {
        DragGestureView(
            onDragStarted: {
                if !isAnyDragging {
                    onDragStarted()
                    isLifted = true
                }
            },
            onDragChanged: { translation in
                dragOffset = translation
                onDragChanged(translation)
            },
            onDragEnded: { translation in
                onDragEnded(translation)
                isLifted = false
                dragOffset = .zero
            },
            contextMenuConfig: ContextMenuConfig(
                onHide: onHide,
                onEditCrop: onEditCrop,
                onDelete: onDelete,
                previewProvider: { [image, aspectRatio] in
                    // Create a preview with crop applied
                    let previewView = ImagePreviewView(image: image, aspectRatio: aspectRatio)
                    let hostingController = UIHostingController(rootView: previewView)
                    hostingController.view.backgroundColor = .clear
                    return hostingController
                }
            )
        ) {
            imageContainer
                .contentShape(Rectangle())
        }
    }

    // Edit mode content with tap gesture
    @ViewBuilder
    private var editModeContent: some View {
        imageContainer
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
                HapticService.selection()
            }
    }

    // Image container with crop applied
    @ViewBuilder
    private var imageContainer: some View {
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
            .clipShape(Rectangle())
            .contentShape(Rectangle())
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

#Preview {
    PhotoGridCell(
        image: PlanImage(localPath: "", width: 100, height: 100, order: 0),
        size: CGSize(width: 120, height: 150),
        isSelected: false,
        editMode: false,
        isDragging: false,
        isAnyDragging: false,
        aspectRatio: .feedPortrait,
        index: 0,
        onTap: {},
        onDelete: {},
        onHide: {},
        onEditCrop: {},
        onDragStarted: {},
        onDragChanged: { _ in },
        onDragEnded: { _ in }
    )
}
