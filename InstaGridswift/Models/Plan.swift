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

    var sortedImages: [PlanImage] {
        images.sorted { $0.order < $1.order }
    }

    var thumbnailImages: [PlanImage] {
        Array(sortedImages.prefix(9))
    }

    var imageCount: Int {
        images.count
    }
}
