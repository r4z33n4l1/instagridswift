//
//  Plan.swift
//  InstaGridswift
//

import SwiftData
import Foundation

@Model
final class Plan {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \PlanImage.plan)
    var images: [PlanImage]
    var createdAt: Date
    var updatedAt: Date
    var aspectRatioRaw: String = AspectRatio.feedPortrait.rawValue

    init(name: String, aspectRatio: AspectRatio = .feedPortrait) {
        self.id = UUID()
        self.name = name
        self.images = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.aspectRatioRaw = aspectRatio.rawValue
    }

    var aspectRatio: AspectRatio {
        get { AspectRatio(rawValue: aspectRatioRaw) ?? .feedPortrait }
        set { aspectRatioRaw = newValue.rawValue }
    }

    // Visible images only, sorted by order
    var sortedImages: [PlanImage] {
        images.filter { !$0.isHidden }.sorted { $0.order < $1.order }
    }

    // Hidden images, sorted by when they were hidden (most recent first)
    var hiddenImages: [PlanImage] {
        images.filter { $0.isHidden }.sorted { ($0.hiddenAt ?? Date.distantPast) > ($1.hiddenAt ?? Date.distantPast) }
    }

    var thumbnailImages: [PlanImage] {
        Array(sortedImages.prefix(9))
    }

    // Count of visible images
    var imageCount: Int {
        sortedImages.count
    }

    // Count of hidden images
    var hiddenImageCount: Int {
        images.filter { $0.isHidden }.count
    }
}
