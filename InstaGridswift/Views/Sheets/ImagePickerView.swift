//
//  ImagePickerView.swift
//  InstaGridswift
//

import PhotosUI
import SwiftUI
import SwiftData

struct ImagePickerView: View {
    let plan: Plan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 30,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ContentUnavailableView(
                        "Select Photos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Choose photos to add to your plan")
                    )
                }
                .photosPickerStyle(.inline)
                .photosPickerDisabledCapabilities(.selectionActions)
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.5 : 1)

                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Button("Add \(selectedItems.count)") {
                            addPhotos()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedItems.isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isProcessing)
        }
    }

    @ViewBuilder
    private var processingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(processedCount), total: Double(totalCount))
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("Adding \(processedCount) of \(totalCount)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.scale.combined(with: .opacity))
    }

    private func addPhotos() {
        guard !isProcessing else { return }

        isProcessing = true
        totalCount = selectedItems.count
        processedCount = 0
        HapticService.impact(.medium)

        Task {
            var currentOrder = plan.images.count

            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {

                    if let savedPath = await ImageStorageService.shared.saveImage(
                        data,
                        planID: plan.id
                    ) {
                        let planImage = PlanImage(
                            localPath: savedPath,
                            width: Int(uiImage.size.width),
                            height: Int(uiImage.size.height),
                            order: currentOrder
                        )
                        planImage.plan = plan
                        modelContext.insert(planImage)
                        currentOrder += 1
                    }
                }

                await MainActor.run {
                    withAnimation(.snappySpring) {
                        processedCount += 1
                    }
                }
            }

            plan.updatedAt = Date()
            HapticService.notification(.success)
            dismiss()
        }
    }
}

#Preview {
    ImagePickerView(plan: Plan(name: "Test"))
}
