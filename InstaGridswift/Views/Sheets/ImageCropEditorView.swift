//
//  ImageCropEditorView.swift
//  InstaGridswift
//

import SwiftUI

struct ImageCropEditorView: View {
    @Bindable var image: PlanImage
    let aspectRatio: AspectRatio
    @Environment(\.dismiss) private var dismiss

    // Current state
    @State private var currentOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var hasChanges = false
    @State private var frameSize: CGSize = .zero

    // Gesture state
    @GestureState private var gestureOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0

    // Image aspect ratio from original dimensions
    private var imageAspectRatio: CGFloat {
        guard image.height > 0 else { return 1.0 }
        return CGFloat(image.width) / CGFloat(image.height)
    }

    // Frame aspect ratio
    private var frameAspectRatio: CGFloat {
        aspectRatio.value
    }

    // Calculate displayed image size when it fills the frame
    private func displayedImageSize(for frameSize: CGSize) -> CGSize {
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

    // Calculate max pan offsets
    private func maxOffset(for frameSize: CGSize, scale: CGFloat) -> CGSize {
        let displayedSize = displayedImageSize(for: frameSize)
        let scaledWidth = displayedSize.width * scale
        let scaledHeight = displayedSize.height * scale

        // How much the image extends beyond the frame on each side
        let extraWidth = max(0, (scaledWidth - frameSize.width) / 2)
        let extraHeight = max(0, (scaledHeight - frameSize.height) / 2)

        return CGSize(width: extraWidth, height: extraHeight)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geometry in
                    let calculatedFrameSize = calculateFrameSize(in: geometry.size)

                    VStack(spacing: 24) {
                        Spacer()

                        // Aspect ratio badge
                        Text(aspectRatio.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.1))
                            .clipShape(Capsule())

                        // Crop frame with image
                        cropFrame(frameSize: calculatedFrameSize)
                            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                            .onAppear {
                                frameSize = calculatedFrameSize
                                loadExistingSettings()
                            }
                            .onChange(of: calculatedFrameSize) { _, newSize in
                                frameSize = newSize
                            }

                        // Instructions
                        Text("Drag to reposition • Pinch to zoom")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        Spacer()

                        controlsSection
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Adjust Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCropSettings() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasChanges)
    }

    @ViewBuilder
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Zoom slider
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))
                    Slider(value: $currentScale, in: 1.0...3.0)
                        .tint(.blue)
                        .onChange(of: currentScale) { oldValue, newValue in
                            hasChanges = true
                            // Constrain offset when zoom changes
                            currentOffset = constrainOffset(currentOffset, scale: newValue)
                        }
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal)

                Text("Zoom: \(Int(currentScale * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Reset button
            Button {
                withAnimation(.smoothSpring) {
                    currentOffset = .zero
                    currentScale = 1.0
                    hasChanges = false
                }
                HapticService.impact(.light)
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .disabled(currentOffset == .zero && currentScale == 1.0)
            .opacity(currentOffset == .zero && currentScale == 1.0 ? 0.4 : 1.0)
        }
        .padding(.bottom, 30)
    }

    @ViewBuilder
    private func cropFrame(frameSize: CGSize) -> some View {
        let displayedSize = displayedImageSize(for: frameSize)
        let combinedScale = max(1.0, currentScale * gestureScale)
        let combinedOffset = CGSize(
            width: currentOffset.width + gestureOffset.width,
            height: currentOffset.height + gestureOffset.height
        )

        ZStack {
            if let url = image.fileURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let loadedImage):
                        loadedImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        errorPlaceholder
                    case .empty:
                        loadingPlaceholder
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(
                    width: displayedSize.width * combinedScale,
                    height: displayedSize.height * combinedScale
                )
                .offset(x: combinedOffset.width, y: combinedOffset.height)
            } else {
                errorPlaceholder
            }

            gridOverlay()
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .clipped()
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white, lineWidth: 2)
        }
        .gesture(dragGesture(frameSize: frameSize))
        .gesture(magnificationGesture(frameSize: frameSize))
    }

    private func dragGesture(frameSize: CGSize) -> some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let newOffset = CGSize(
                    width: currentOffset.width + value.translation.width,
                    height: currentOffset.height + value.translation.height
                )
                currentOffset = constrainOffset(newOffset, scale: currentScale)
                hasChanges = true
            }
    }

    private func magnificationGesture(frameSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = max(1.0, min(3.0, currentScale * value))
                currentScale = newScale
                currentOffset = constrainOffset(currentOffset, scale: newScale)
                hasChanges = true
                HapticService.impact(.light)
            }
    }

    @ViewBuilder
    private func gridOverlay() -> some View {
        ZStack {
            // Vertical lines (rule of thirds)
            HStack {
                ForEach(0..<2, id: \.self) { _ in
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 0.5)
                }
                Spacer()
            }

            // Horizontal lines
            VStack {
                ForEach(0..<2, id: \.self) { _ in
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 0.5)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var loadingPlaceholder: some View {
        Color.gray.opacity(0.3)
            .overlay {
                ProgressView()
                    .tint(.white)
            }
    }

    @ViewBuilder
    private var errorPlaceholder: some View {
        Color.gray.opacity(0.3)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                    Text("Unable to load")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
            }
    }

    private func calculateFrameSize(in containerSize: CGSize) -> CGSize {
        let maxWidth = containerSize.width - 48
        let maxHeight = containerSize.height - 280
        let ratio = aspectRatio.value

        if maxWidth / ratio <= maxHeight {
            return CGSize(width: maxWidth, height: maxWidth / ratio)
        } else {
            return CGSize(width: maxHeight * ratio, height: maxHeight)
        }
    }

    private func constrainOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        guard frameSize.width > 0 && frameSize.height > 0 else { return offset }

        let maxOff = maxOffset(for: frameSize, scale: scale)

        return CGSize(
            width: max(-maxOff.width, min(maxOff.width, offset.width)),
            height: max(-maxOff.height, min(maxOff.height, offset.height))
        )
    }

    private func loadExistingSettings() {
        let settings = image.cropSettings(for: aspectRatio)
        let maxOff = maxOffset(for: frameSize, scale: max(1.0, settings.scale))

        // Convert normalized offsets back to actual offsets
        currentOffset = CGSize(
            width: settings.offsetX * maxOff.width,
            height: settings.offsetY * maxOff.height
        )
        currentScale = max(1.0, settings.scale)
    }

    private func saveCropSettings() {
        let maxOff = maxOffset(for: frameSize, scale: currentScale)

        // Normalize offsets to -1...1 range
        let normalizedX = maxOff.width > 0 ? currentOffset.width / maxOff.width : 0
        let normalizedY = maxOff.height > 0 ? currentOffset.height / maxOff.height : 0

        let settings = CropSettings(
            offsetX: normalizedX,
            offsetY: normalizedY,
            scale: currentScale
        )
        image.setCropSettings(settings, for: aspectRatio)
        HapticService.notification(.success)
        dismiss()
    }
}

#Preview {
    ImageCropEditorView(
        image: PlanImage(localPath: "", width: 1080, height: 1920, order: 0),
        aspectRatio: .feedPortrait
    )
}
