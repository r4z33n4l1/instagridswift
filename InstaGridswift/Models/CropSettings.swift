//
//  CropSettings.swift
//  InstaGridswift
//

import Foundation

/// Stores crop/zoom settings for a single aspect ratio
struct CropSettings: Codable, Equatable {
    var offsetX: CGFloat = 0     // Pan offset X (normalized -1 to 1)
    var offsetY: CGFloat = 0     // Pan offset Y (normalized -1 to 1)
    var scale: CGFloat = 1.0     // Zoom scale (1.0 = fit, >1 = zoomed in)

    static let `default` = CropSettings()
}

/// Dictionary wrapper for storing crop settings per aspect ratio
/// Key is AspectRatio.rawValue, Value is CropSettings
typealias CropSettingsMap = [String: CropSettings]
