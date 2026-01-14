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
    @State private var showHiddenSheet = false
    @State private var imageToEdit: PlanImage?

    // Drag state
    @State private var draggedSourceIndex: Int?
    @State private var proposedDropIndex: Int?
    @State private var currentItemSize: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let itemSize = calculateItemSize(for: geometry.size.width)

            ZStack {
                ScrollView {
                    Group {
                        if plan.images.isEmpty {
                            emptyState
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            gridContent(itemSize: itemSize, geometry: geometry)
                                .transition(.opacity)
                        }
                    }
                    .animation(.smoothSpring, value: plan.images.isEmpty)
                }
                .scrollDisabled(draggedSourceIndex != nil)  // Disable scroll during drag

                // Floating drag preview
                if let sourceIndex = draggedSourceIndex,
                   sourceIndex < plan.sortedImages.count {
                    dragPreview(for: plan.sortedImages[sourceIndex], itemSize: itemSize)
                }
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
        .sheet(isPresented: $showHiddenSheet) {
            HiddenImagesSheet(plan: plan)
        }
        .sheet(item: $imageToEdit) { image in
            ImageCropEditorView(image: image, aspectRatio: plan.aspectRatio)
        }
        .onAppear {
            editedName = plan.name
        }
    }

    private func calculateItemSize(for width: CGFloat) -> CGSize {
        guard width > 0 else { return CGSize(width: 100, height: 100) }
        let spacing = GridConstants.spacing
        let columns = CGFloat(GridConstants.columns)
        let totalSpacing = spacing * (columns + 1)
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
    private func gridContent(itemSize: CGSize, geometry: GeometryProxy) -> some View {
        let draggedID = draggedSourceIndex.map { plan.sortedImages[$0].id }

        AnimatedReorderableGrid(
            items: plan.sortedImages,
            columns: GridConstants.columns,
            spacing: GridConstants.spacing,
            itemSize: itemSize,
            draggedItemID: draggedID,
            draggedSourceIndex: draggedSourceIndex,
            proposedDropIndex: proposedDropIndex
        ) { image, index in
            PhotoGridCell(
                image: image,
                size: itemSize,
                isSelected: selectedImageIDs.contains(image.id),
                editMode: editMode,
                isDragging: draggedSourceIndex == index,
                aspectRatio: plan.aspectRatio,
                index: index,
                onTap: { handleTap(image) },
                onDelete: { deleteImage(image) },
                onHide: { hideImage(image) },
                onEditCrop: { imageToEdit = image },
                onDragChanged: { sourceIndex, translation in
                    dragTranslation = translation
                    handleDragChanged(sourceIndex: sourceIndex, translation: translation, itemSize: itemSize)
                },
                onDragEnded: {
                    handleDragEnded()
                }
            )
        }
        .onAppear {
            currentItemSize = itemSize
        }
        .onChange(of: itemSize) { _, newSize in
            currentItemSize = newSize
        }
    }

    @ViewBuilder
    private func dragPreview(for image: PlanImage, itemSize: CGSize) -> some View {
        // Calculate the original position of the dragged cell
        guard let sourceIndex = draggedSourceIndex else { return AnyView(EmptyView()) }

        let cellWidth = itemSize.width + GridConstants.spacing
        let cellHeight = itemSize.height + GridConstants.spacing
        let sourceCol = sourceIndex % GridConstants.columns
        let sourceRow = sourceIndex / GridConstants.columns

        // Original center position (accounting for grid padding)
        let originalX = CGFloat(sourceCol) * cellWidth + itemSize.width / 2 + GridConstants.spacing
        let originalY = CGFloat(sourceRow) * cellHeight + itemSize.height / 2 + GridConstants.spacing

        // Current position = original + translation
        let currentX = originalX + dragTranslation.width
        let currentY = originalY + dragTranslation.height

        return AnyView(
            CachedAsyncImage(
                url: image.fileURL,
                cacheKey: image.localPath,
                useThumbnail: true
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: itemSize.width, height: itemSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(1.05)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .position(x: currentX, y: currentY)
            .allowsHitTesting(false)
        )
    }

    private func handleDragChanged(sourceIndex: Int, translation: CGSize, itemSize: CGSize) {
        guard !editMode else { return }

        // Set source index on first drag update
        if draggedSourceIndex == nil {
            draggedSourceIndex = sourceIndex
            print("🚀 DRAG started: sourceIndex=\(sourceIndex)")
        }

        // Calculate source cell's original position
        let cellWidth = itemSize.width + GridConstants.spacing
        let cellHeight = itemSize.height + GridConstants.spacing
        let sourceCol = sourceIndex % GridConstants.columns
        let sourceRow = sourceIndex / GridConstants.columns
        let sourceCenterX = CGFloat(sourceCol) * cellWidth + itemSize.width / 2 + GridConstants.spacing
        let sourceCenterY = CGFloat(sourceRow) * cellHeight + itemSize.height / 2 + GridConstants.spacing

        // Calculate current drag position (source center + translation)
        let currentX = sourceCenterX + translation.width
        let currentY = sourceCenterY + translation.height

        // Calculate target index from current position
        let col = max(0, min(GridConstants.columns - 1, Int(currentX / cellWidth)))
        let row = max(0, Int(currentY / cellHeight))
        let newIndex = min(plan.sortedImages.count - 1, max(0, row * GridConstants.columns + col))

        if newIndex != proposedDropIndex {
            print("📍 Target: \(newIndex) (from pos \(Int(currentX)),\(Int(currentY)))")
            proposedDropIndex = newIndex
            HapticService.selection()
        }
    }

    private func handleDragEnded() {
        print("🔚 DRAG ended: src=\(draggedSourceIndex ?? -1), tgt=\(proposedDropIndex ?? -1)")

        guard let sourceIndex = draggedSourceIndex,
              let targetIndex = proposedDropIndex,
              sourceIndex != targetIndex else {
            // Reset state without reordering
            draggedSourceIndex = nil
            proposedDropIndex = nil
            dragTranslation = .zero
            return
        }

        // Perform reorder
        var images = plan.sortedImages
        let movedImage = images.remove(at: sourceIndex)
        images.insert(movedImage, at: targetIndex)

        for (index, image) in images.enumerated() {
            image.order = index
        }

        try? modelContext.save()
        plan.updatedAt = Date()
        print("📍 REORDER: \(sourceIndex) -> \(targetIndex) complete")
        HapticService.notification(.success)

        // Reset state
        draggedSourceIndex = nil
        proposedDropIndex = nil
        dragTranslation = .zero
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

        if plan.hiddenImageCount > 0 {
            Button {
                showHiddenSheet = true
                HapticService.impact(.light)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "eye.slash")

                    Text("\(plan.hiddenImageCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.danger)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
            .accessibilityLabel("\(plan.hiddenImageCount) hidden photos")
        }

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

    private func hideImage(_ image: PlanImage) {
        withAnimation(.smoothSpring) {
            image.isHidden = true
            image.hiddenAt = Date()
            reorderImages()
        }
        plan.updatedAt = Date()
        HapticService.notification(.success)
    }
}

#Preview {
    NavigationStack {
        PlanEditorView(plan: Plan(name: "Test Plan"))
    }
    .modelContainer(for: [Plan.self, PlanImage.self], inMemory: true)
}
