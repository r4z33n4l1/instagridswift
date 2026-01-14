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

    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            imageContent

            if editMode {
                if isSelected {
                    selectionOverlay
                }
                deleteButton
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .shadow(color: .black.opacity(isDragging ? 0.3 : 0), radius: 10, y: 5)
        .zIndex(isDragging ? 100 : 0)
        .offset(dragOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .gesture(editMode ? nil : dragGesture)
        .onTapGesture {
            if editMode {
                onTap()
                HapticService.selection()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photo \(image.order + 1)")
        .accessibilityHint(editMode ? "Double tap to select" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var imageContent: some View {
        if let url = image.fileURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Color.gridItemPlaceholder
                        .overlay {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.secondary)
                        }
                case .empty:
                    Color.gridItemPlaceholder
                        .overlay {
                            ProgressView()
                        }
                @unknown default:
                    Color.gridItemPlaceholder
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        } else {
            Color.gridItemPlaceholder
        }
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

    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(coordinateSpace: .global))
            .updating($dragOffset) { value, state, _ in
                switch value {
                case .second(true, let drag):
                    if let drag = drag {
                        state = drag.translation
                    }
                default:
                    break
                }
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    HapticService.impact(.medium)
                    onDragStarted()
                case .second(true, let drag):
                    if let drag = drag {
                        onDragChanged(drag.translation)
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                onDragEnded()
            }
    }
}

#Preview {
    DraggableGridItem(
        image: PlanImage(localPath: "", width: 100, height: 100, order: 0),
        size: CGSize(width: 120, height: 150),
        isSelected: false,
        editMode: true,
        isDragging: false,
        onTap: {},
        onDelete: {},
        onDragStarted: {},
        onDragChanged: { _ in },
        onDragEnded: {}
    )
}
