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
    @State private var dragSourceIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartLocation: CGPoint = .zero
    @State private var showingOverlayForID: UUID?
    @State private var showHiddenSheet = false
    @State private var imageToEdit: PlanImage?

    var body: some View {
        GeometryReader { geometry in
            let itemSize = calculateItemSize(for: geometry.size.width)

            ZStack {
                ScrollView {
                    ZStack {
                        // Background tap area to dismiss overlay (behind grid content)
                        if showingOverlayForID != nil {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.snappySpring) {
                                        showingOverlayForID = nil
                                    }
                                    HapticService.impact(.light)
                                }
                        }

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

                // Dragged item overlay - always on top
                if let draggedID = draggedImageID,
                   let draggedImage = plan.sortedImages.first(where: { $0.id == draggedID }) {
                    draggedItemOverlay(image: draggedImage, itemSize: itemSize)
                        .zIndex(200) // Highest z-index
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
        .onChange(of: editMode) { _, newValue in
            if newValue {
                showingOverlayForID = nil
            }
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
            // Use enumerated() for stable index-value pairs
            ForEach(Array(plan.sortedImages.enumerated()), id: \.element.id) { index, image in
                DraggableGridItem(
                    image: image,
                    size: itemSize,
                    isSelected: selectedImageIDs.contains(image.id),
                    editMode: editMode,
                    isDragging: draggedImageID == image.id,
                    isDropTarget: dragTargetIndex == index && draggedImageID != nil && draggedImageID != image.id,
                    aspectRatio: plan.aspectRatio,
                    showingOverlayForID: $showingOverlayForID,
                    onTap: { handleTap(image) },
                    onDelete: { deleteImage(image) },
                    onHide: { hideImage(image) },
                    onEditCrop: { imageToEdit = image },
                    onDragStarted: { startLocation in
                        showingOverlayForID = nil
                        draggedImageID = image.id
                        dragSourceIndex = index
                        dragStartLocation = startLocation
                    },
                    onDragChanged: { translation in
                        dragOffset = translation
                        handleDrag(image, translation: translation, itemSize: itemSize)
                    },
                    onDragEnded: {
                        handleDragEnd()
                        dragOffset = .zero
                        dragStartLocation = .zero
                    }
                )
            }
        }
        .padding(GridConstants.spacing)
    }

    @ViewBuilder
    private func draggedItemOverlay(image: PlanImage, itemSize: CGSize) -> some View {
        // Outer container that clips AFTER all crop transforms
        Rectangle()
            .fill(Color.clear)
            .frame(width: itemSize.width, height: itemSize.height)
            .overlay {
                CachedAsyncImage(
                    url: image.fileURL,
                    cacheKey: image.localPath,
                    useThumbnail: true
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: itemSize.width, height: itemSize.height)
                .modifier(CropAppliedModifier(
                    cropSettings: image.cropSettings(for: plan.aspectRatio),
                    frameSize: itemSize,
                    imageWidth: image.width,
                    imageHeight: image.height
                ))
            }
            .clipShape(Rectangle()) // Clips AFTER crop transforms
            .scaleEffect(1.10) // Enhanced lift effect (was 1.05)
            .rotationEffect(.degrees(2)) // Subtle rotation for "picked up" feel
            .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
            .position(
                x: dragStartLocation.x + dragOffset.width,
                y: dragStartLocation.y + dragOffset.height
            )
            .allowsHitTesting(false)
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

    private func handleDrag(_ image: PlanImage, translation: CGSize, itemSize: CGSize) {
        guard draggedImageID != nil, let sourceIndex = dragSourceIndex else { return }

        let cellWidth = itemSize.width + GridConstants.spacing
        let cellHeight = itemSize.height + GridConstants.spacing

        // Calculate cell offset from translation
        // Since we now start from cell CENTER, simple rounding works correctly
        let colOffset = Int(round(translation.width / cellWidth))
        let rowOffset = Int(round(translation.height / cellHeight))

        let sourceRow = sourceIndex / GridConstants.columns
        let sourceCol = sourceIndex % GridConstants.columns

        let newCol = max(0, min(GridConstants.columns - 1, sourceCol + colOffset))
        let newRow = max(0, sourceRow + rowOffset)

        let totalImages = plan.sortedImages.count
        let maxIndex = max(0, totalImages - 1)
        let newIndex = min(maxIndex, max(0, newRow * GridConstants.columns + newCol))

        // Only update target index for visual feedback
        if newIndex != dragTargetIndex {
            dragTargetIndex = newIndex
            HapticService.selection()
        }
    }

    private func handleDragEnd() {
        defer {
            draggedImageID = nil
            dragTargetIndex = nil
            dragSourceIndex = nil
        }

        // Perform the actual move only on drag end
        guard let sourceIndex = dragSourceIndex,
              let targetIndex = dragTargetIndex,
              sourceIndex != targetIndex else {
            plan.updatedAt = Date()
            return
        }

        withAnimation(.smoothSpring) {
            moveImage(from: sourceIndex, to: targetIndex)
        }
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
