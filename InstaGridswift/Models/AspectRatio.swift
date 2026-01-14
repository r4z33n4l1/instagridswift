//
//  AspectRatio.swift
//  InstaGridswift
//

import Foundation

enum AspectRatio: String, Codable, CaseIterable, Identifiable {
    case profilePhoto      // 1:1 (320x320)
    case profileGrid       // 3:4 (1012.5x1350)
    case feedPortrait      // 4:5 (1080x1350)
    case reelsStories      // 9:16 (1080x1920)
    case feedLandscape     // 1.91:1 (1080x566)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .profilePhoto: return "Profile Photo (1:1)"
        case .profileGrid: return "Profile Grid (3:4)"
        case .feedPortrait: return "Feed Portrait (4:5)"
        case .reelsStories: return "Reels & Stories (9:16)"
        case .feedLandscape: return "Feed Landscape (1.91:1)"
        }
    }

    var shortName: String {
        switch self {
        case .profilePhoto: return "1:1"
        case .profileGrid: return "3:4"
        case .feedPortrait: return "4:5"
        case .reelsStories: return "9:16"
        case .feedLandscape: return "1.91:1"
        }
    }

    /// Width divided by height ratio value
    var value: CGFloat {
        switch self {
        case .profilePhoto: return 1.0           // 1:1
        case .profileGrid: return 3.0 / 4.0      // 0.75
        case .feedPortrait: return 4.0 / 5.0     // 0.8
        case .reelsStories: return 9.0 / 16.0    // 0.5625
        case .feedLandscape: return 1.91         // 1.91:1
        }
    }

    var icon: String {
        switch self {
        case .profilePhoto: return "square"
        case .profileGrid: return "rectangle.portrait"
        case .feedPortrait: return "rectangle.portrait"
        case .reelsStories: return "rectangle.portrait.fill"
        case .feedLandscape: return "rectangle"
        }
    }
}
