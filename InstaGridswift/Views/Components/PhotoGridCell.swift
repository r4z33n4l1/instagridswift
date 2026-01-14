//
//  PhotoGridCell.swift
//  InstaGridswift
//

import SwiftUI

struct PhotoGridCell: View {
    let image: PlanImage
    let size: CGSize
    let isSelected: Bool
    let editMode: Bool
    let isDragging: Bool
    let aspectRatio: AspectRatio
    let index: Int

    let onTap: () -> Void
    let onDelete: () -> Void
    let onHide: () -> Void
    let onEditCrop: () -> Void
    let onDragChanged: (Int, CGSize) -> Void  // index, translation
    let onDragEnded: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDragActive = false

    var body: some View {
        // Only log when dragging state changes (reduce spam)
        let _ = isDragging ? print("📷 Cell[\(image.order)] dragging") : ()

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
        .opacity(isDragging ? 0.3 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photo \(image.order + 1)")
        .accessibilityHint(editMode ? "Double tap to select" : "Long press for options")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // Drag gesture for reordering
    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    if let drag = drag {
                        if !isDragActive {
                            isDragActive = true
                            HapticService.impact(.medium)
                            print("🚀 DRAG started: index=\(index)")
                        }
                        // Pass translation to calculate new position
                        onDragChanged(index, drag.translation)
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                if isDragActive {
                    print("🔚 DRAG ended: index=\(index)")
                    isDragActive = false
                    onDragEnded()
                }
            }
    }

    // Normal content with context menu
    @ViewBuilder
    private var normalContent: some View {
        imageContainer
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .contextMenu {
                // Share action
                if let url = image.fileURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }

                Button {
                    onHide()
                } label: {
                    Label("Hide", systemImage: "eye.slash")
                }

                Button {
                    onEditCrop()
                } label: {
                    Label("Crop", systemImage: "crop")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } preview: {
                ImagePreviewView(image: image)
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
        aspectRatio: .feedPortrait,
        index: 0,
        onTap: {},
        onDelete: {},
        onHide: {},
        onEditCrop: {},
        onDragChanged: { _, _ in },  // index, translation
        onDragEnded: {}
    )
}
