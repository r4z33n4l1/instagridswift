//
//  PlanImage.swift
//  InstaGridswift
//

import SwiftData
import Foundation

@Model
final class PlanImage {
    var id: UUID
    var localPath: String
    var originalAssetID: String?
    var width: Int
    var height: Int
    var order: Int
    var addedAt: Date
    var plan: Plan?

    init(localPath: String, width: Int, height: Int, order: Int) {
        self.id = UUID()
        self.localPath = localPath
        self.width = width
        self.height = height
        self.order = order
        self.addedAt = Date()
    }

    var fileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent(localPath)
    }
}
