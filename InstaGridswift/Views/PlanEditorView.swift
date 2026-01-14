//
//  PlanEditorView.swift
//  InstaGridswift
//

import SwiftUI
import SwiftData

struct PlanEditorView: View {
    @Bindable var plan: Plan
    @Environment(\.modelContext) private var modelContext
    @State private var isEditingTitle = false
    @State private var editedName: String = ""
    @State private var editMode = false
    @State private var selectedImageIDs: Set<UUID> = []
    @State private var showImagePicker = false
    @State private var draggedImageID: UUID?
    @State private var dragTargetIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            let itemSize = calculateItemSize(for: geometry.size.width)

            ScrollView {
                Group {
                    if plan.images.isEmpty {
                        emptyState
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        gridContent(itemSize: itemSize, containerWidth: geometry.size.width)
                            .transition(.opacity)
                    }
                }
                .animation(.smoothSpring, value: plan.images.isEmpty)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                titleView
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                toolbarContent
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(plan: plan)
        }
        .onAppear {
            editedName = plan.name
        }
    }

    private func calculateItemSize(for width: CGFloat) -> CGSize {
        guard width > 0 else { return CGSize(width: 100, height: 100) }
        let spacing = GridConstants.spacing
        let columns = CGFloat(GridConstants.columns)
        let totalSpacing = spacing * (columns - 1)
        let itemWidth = max(1, (width - totalSpacing) / columns)
        let itemHeight = itemWidth / plan.aspectRatio.value
        return CGSize(width: itemWidth, height: itemHeight)
    }

    @ViewBuilder
    private var emptyState: some View {
        EmptyStateView(
            icon: "photo.badge.plus",
            title: "No photos yet",
            subtitle: "Add photos to start planning your grid",
            buttonTitle: "Add Photos",
            action: { showImagePicker = true }
        )
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    @ViewBuilder
    private func gridContent(itemSize: CGSize, containerWidth: CGFloat) -> some View {
        let columns = Array(
            repeating: GridItem(.fixed(itemSize.width), spacing: GridConstants.spacing),
            count: GridConstants.columns
        )

        LazyVGrid(columns: columns, spacing: GridConstants.spacing) {
            ForEach(plan.sortedImages) { image in
                DraggableGridItem(
                    image: image,
                    size: itemSize,
                    isSelected: selectedImageIDs.contains(image.id),
                    editMode: editMode,
                    isDragging: draggedImageID == image.id,
                    onTap: { handleTap(image) },
                    onDelete: { deleteImage(image) },
                    onDragStarted: { draggedImageID = image.id },
                    onDragChanged: { translation in
                        handleDrag(image, translation: translation, itemSize: itemSize)
                    },
                    onDragEnded: { handleDragEnd() }
                )
                .id(image.id)
            }
        }
        .padding(GridConstants.spacing)
    }

    @ViewBuilder
    private var titleView: some View {
        if isEditingTitle {
            TextField("Plan name", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .onSubmit {
                    plan.name = editedName
                    isEditingTitle = false
                    HapticService.impact(.light)
                }
        } else {
            Button {
                isEditingTitle = true
                HapticService.impact(.light)
            } label: {
                HStack(spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var toolbarContent: some View {
        if editMode {
            editModeToolbar
        } else {
            normalToolbar
        }
    }

    @ViewBuilder
    private var normalToolbar: some View {
        Menu {
            ForEach(AspectRatio.allCases) { ratio in
                Button {
                    withAnimation(.smoothSpring) {
                        plan.aspectRatio = ratio
                        plan.updatedAt = Date()
                    }
                    HapticService.selection()
                } label: {
                    HStack {
                        Label(ratio.displayName, systemImage: ratio.icon)
                        if plan.aspectRatio == ratio {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: plan.aspectRatio.icon)
                Text(plan.aspectRatio.shortName)
                    .font(.caption)
            }
        }
        .accessibilityLabel("Aspect ratio: \(plan.aspectRatio.displayName)")

        if !plan.images.isEmpty {
            Button {
                HapticService.impact(.light)
                withAnimation(.smoothSpring) {
                    editMode = true
                }
            } label: {
                Image(systemName: "pencil.circle")
            }
            .accessibilityLabel("Edit photos")
        }

        Button {
            HapticService.impact(.light)
            showImagePicker = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add photos")
    }

    @ViewBuilder
    private var editModeToolbar: some View {
        if !selectedImageIDs.isEmpty {
            Text("\(selectedImageIDs.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                HapticService.impact(.medium)
                deleteSelectedImages()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.danger)
            }
            .accessibilityLabel("Delete selected photos")
        }

        Button {
            withAnimation(.smoothSpring) {
                editMode = false
                selectedImageIDs.removeAll()
            }
            HapticService.impact(.light)
        } label: {
            Text("Done")
                .fontWeight(.semibold)
        }
        .accessibilityLabel("Exit edit mode")
    }

    private func handleTap(_ image: PlanImage) {
        if editMode {
            withAnimation(.snappySpring) {
                if selectedImageIDs.contains(image.id) {
                    selectedImageIDs.remove(image.id)
                } else {
                    selectedImageIDs.insert(image.id)
                }
            }
        }
    }

    private func handleDrag(_ image: PlanImage, translation: CGSize, itemSize: CGSize) {
        guard draggedImageID != nil else { return }

        let currentIndex = plan.sortedImages.firstIndex(where: { $0.id == image.id }) ?? 0
        let currentRow = currentIndex / GridConstants.columns
        let currentCol = currentIndex % GridConstants.columns

        let cellWidth = itemSize.width + GridConstants.spacing
        let cellHeight = itemSize.height + GridConstants.spacing
        let colOffset = Int(round(translation.width / cellWidth))
        let rowOffset = Int(round(translation.height / cellHeight))

        let newCol = max(0, min(GridConstants.columns - 1, currentCol + colOffset))
        let newRow = max(0, currentRow + rowOffset)
        let newIndex = min(plan.images.count - 1, newRow * GridConstants.columns + newCol)

        if newIndex != dragTargetIndex && newIndex != currentIndex {
            dragTargetIndex = newIndex
            moveImage(from: currentIndex, to: newIndex)
            HapticService.selection()
        }
    }

    private func handleDragEnd() {
        draggedImageID = nil
        dragTargetIndex = nil
        plan.updatedAt = Date()
    }

    private func moveImage(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex != targetIndex else { return }

        var images = plan.sortedImages
        let movedImage = images.remove(at: sourceIndex)
        images.insert(movedImage, at: targetIndex)

        for (index, image) in images.enumerated() {
            image.order = index
        }
    }

    private func deleteImage(_ image: PlanImage) {
        Task {
            await ImageStorageService.shared.deleteImage(at: image.localPath)
        }
        withAnimation(.smoothSpring) {
            modelContext.delete(image)
            reorderImages()
        }
        plan.updatedAt = Date()
        HapticService.notification(.success)
    }

    private func deleteSelectedImages() {
        let imagesToDelete = plan.images.filter { selectedImageIDs.contains($0.id) }

        Task {
            for image in imagesToDelete {
                await ImageStorageService.shared.deleteImage(at: image.localPath)
            }
        }

        withAnimation(.smoothSpring) {
            for image in imagesToDelete {
                modelContext.delete(image)
            }
            selectedImageIDs.removeAll()

            if plan.images.isEmpty {
                editMode = false
            }

            reorderImages()
        }
        plan.updatedAt = Date()
        HapticService.notification(.success)
    }

    private func reorderImages() {
        for (index, image) in plan.sortedImages.enumerated() {
            image.order = index
        }
    }
}

#Preview {
    NavigationStack {
        PlanEditorView(plan: Plan(name: "Test Plan"))
    }
    .modelContainer(for: [Plan.self, PlanImage.self], inMemory: true)
}
