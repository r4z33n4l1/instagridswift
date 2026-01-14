//
//  PlanCard.swift
//  InstaGridswift
//

import SwiftUI
import SwiftData

struct PlanCard: View {
    let plan: Plan
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false

    private var thumbnailHeight: CGFloat {
        let thumbnailWidth: CGFloat = 90
        let spacing = GridConstants.thumbnailSpacing
        let columnsCount = CGFloat(GridConstants.columns)
        let totalSpacing = spacing * (columnsCount - 1)
        let itemWidth = (thumbnailWidth - totalSpacing) / columnsCount
        let itemHeight = itemWidth / plan.aspectRatio.value
        // 3 rows with spacing, capped at reasonable max
        return min((itemHeight * 3) + (spacing * 2), 160)
    }

    var body: some View {
        HStack(spacing: 16) {
            ThumbnailGrid(images: plan.thumbnailImages, aspectRatio: plan.aspectRatio)
                .frame(width: 90, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("\(plan.imageCount) photos")
                    Text("•")
                    Text(plan.aspectRatio.shortName)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                HapticService.impact(.light)
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(Color.danger)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete plan")
            .accessibilityHint("Double tap to delete \(plan.name)")
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.name), \(plan.imageCount) photos, \(plan.aspectRatio.shortName) aspect ratio")
        .accessibilityHint("Double tap to open and edit this plan")
        .confirmationDialog("Delete Plan?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text("This will permanently delete '\(plan.name)' and all its photos.")
        }
    }

    private func deletePlan() {
        HapticService.impact(.medium)
        Task {
            await ImageStorageService.shared.deletePlanImages(plan)
        }
        withAnimation(.smoothSpring) {
            modelContext.delete(plan)
        }
        HapticService.notification(.success)
    }
}

#Preview {
    PlanCard(plan: Plan(name: "Test Plan"))
        .padding()
}
