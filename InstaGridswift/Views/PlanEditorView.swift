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

    // Drag state for smooth custom drag/drop
    @State private var draggedSourceIndex: Int?
    @State private var proposedDropIndex: Int?
    @State private var currentItemSize: CGSize = .zero
    @State private var globalDragPosition: CGPoint = .zero

    var body: some View {
        GeometryReader { geometry in
            let itemSize = calculateItemSize(for: geometry.size.width)

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
                isAnyDragging: draggedSourceIndex != nil,
                aspectRatio: plan.aspectRatio,
                index: index,
                onTap: { handleTap(image) },
                onDelete: { deleteImage(image) },
                onHide: { hideImage(image) },
                onEditCrop: { imageToEdit = image },
                onDragStarted: {
                    draggedSourceIndex = index
                },
                onDragChanged: { translation in
                    updateDropIndex(for: translation, sourceIndex: index, itemSize: itemSize, geometry: geometry)
                },
                onDragEnded: { _ in
                    if let sourceIndex = draggedSourceIndex,
                       let targetIndex = proposedDropIndex,
                       sourceIndex != targetIndex {
                        performReorder(from: sourceIndex, to: targetIndex)
                    } else {
                        // Reset state if no valid drop
                        draggedSourceIndex = nil
                        proposedDropIndex = nil
                    }
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

    private func updateDropIndex(for translation: CGSize, sourceIndex: Int, itemSize: CGSize, geometry: GeometryProxy) {
        // Calculate the grid position based on translation
        let gridSpacing = GridConstants.spacing
        let columns = GridConstants.columns
        
        // Get the source position in the grid
        let sourceRow = sourceIndex / columns
        let sourceCol = sourceIndex % columns
        
        // Calculate the source position in points
        let sourceX = CGFloat(sourceCol) * (itemSize.width + gridSpacing) + gridSpacing
        let sourceY = CGFloat(sourceRow) * (itemSize.height + gridSpacing) + gridSpacing
        
        // Add the translation to get the current position
        let currentX = sourceX + translation.width
        let currentY = sourceY + translation.height
        
        // Convert back to grid coordinates
        let cellWidth = itemSize.width + gridSpacing
        let cellHeight = itemSize.height + gridSpacing
        
        let targetCol = max(0, min(columns - 1, Int((currentX - gridSpacing + cellWidth/2) / cellWidth)))
        let targetRow = max(0, Int((currentY - gridSpacing + cellHeight/2) / cellHeight))
        let targetIndex = min(plan.sortedImages.count - 1, max(0, targetRow * columns + targetCol))
        
        if targetIndex != proposedDropIndex {
            proposedDropIndex = targetIndex
            HapticService.selection()
        }
    }

    private func performReorder(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex != targetIndex else {
            draggedSourceIndex = nil
            proposedDropIndex = nil
            return
        }

        var images = plan.sortedImages
        let movedImage = images.remove(at: sourceIndex)
        images.insert(movedImage, at: targetIndex)

        for (index, image) in images.enumerated() {
            image.order = index
        }

        try? modelContext.save()
        plan.updatedAt = Date()
        HapticService.notification(.success)

        // Reset state
        draggedSourceIndex = nil
        proposedDropIndex = nil
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
