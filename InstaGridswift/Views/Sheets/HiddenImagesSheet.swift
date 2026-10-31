//
//  HiddenImagesSheet.swift
//  InstaGridswift
//

import SwiftUI

struct HiddenImagesSheet: View {
    @Bindable var plan: Plan
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if plan.hiddenImages.isEmpty {
                    ContentUnavailableView(
                        "No Hidden Photos",
                        systemImage: "eye.slash",
                        description: Text("Photos you hide will appear here")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(plan.hiddenImages) { image in
                                HiddenImageThumbnail(image: image) {
                                    unhideImage(image)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Hidden Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func unhideImage(_ image: PlanImage) {
        withAnimation(.smoothSpring) {
            image.isHidden = false
            image.hiddenAt = nil
            // Append to end of visible images
            image.order = plan.sortedImages.count
            plan.updatedAt = Date()
        }
        HapticService.notification(.success)
    }
}

private struct HiddenImageThumbnail: View {
    let image: PlanImage
    let onUnhide: () -> Void

    var body: some View {
        Button(action: onUnhide) {
            ZStack(alignment: .bottomTrailing) {
                if let url = image.fileURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let loadedImage):
                            loadedImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            Color.gridItemPlaceholder
                        @unknown default:
                            Color.gridItemPlaceholder
                        }
                    }
                } else {
                    Color.gridItemPlaceholder
                }

                // Unhide indicator
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(4)
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hidden photo")
        .accessibilityHint("Tap to restore to grid")
    }
}

#Preview {
    HiddenImagesSheet(plan: Plan(name: "Test"))
}
