//
//  Color+Theme.swift
//  InstaGridswift
//

import SwiftUI

// MARK: - Adaptive Colors

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    static let primaryAccent = Color(
        light: Color(red: 0, green: 0.58, blue: 0.96),
        dark: Color(red: 0.25, green: 0.65, blue: 1.0)
    )

    static let danger = Color(
        light: Color(red: 0.93, green: 0.29, blue: 0.34),
        dark: Color(red: 1.0, green: 0.45, blue: 0.5)
    )

    static let success = Color(
        light: Color(red: 0.35, green: 0.76, blue: 0.13),
        dark: Color(red: 0.45, green: 0.85, blue: 0.3)
    )

    static let gridBackground = Color(uiColor: .systemGray6)
    static let gridItemPlaceholder = Color(uiColor: .systemGray5)
    static let selectionTint = Color.blue.opacity(0.4)
    static let selectionBorder = Color.blue
}

// MARK: - Animation Constants

extension Animation {
    static let smoothSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let snappySpring = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let gentleSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)
}

// MARK: - Layout Constants

enum GridConstants {
    static let spacing: CGFloat = 2
    static let columns: Int = 3
    static let thumbnailSpacing: CGFloat = 1
}

enum GestureConstants {
    static let longPressDuration: Double = 0.5
}
