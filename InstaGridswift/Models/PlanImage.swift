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

    // Hidden state
    var isHidden: Bool = false
    var hiddenAt: Date?

    // Crop settings per aspect ratio (stored as JSON Data)
    var cropSettingsData: Data?

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

    // Computed property to access crop settings map
    var cropSettingsMap: CropSettingsMap {
        get {
            guard let data = cropSettingsData else { return [:] }
            return (try? JSONDecoder().decode(CropSettingsMap.self, from: data)) ?? [:]
        }
        set {
            cropSettingsData = try? JSONEncoder().encode(newValue)
        }
    }

    // Get crop settings for a specific aspect ratio
    func cropSettings(for ratio: AspectRatio) -> CropSettings {
        cropSettingsMap[ratio.rawValue] ?? .default
    }

    // Set crop settings for a specific aspect ratio
    func setCropSettings(_ settings: CropSettings, for ratio: AspectRatio) {
        var map = cropSettingsMap
        map[ratio.rawValue] = settings
        cropSettingsMap = map
    }
}
