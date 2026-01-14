//
//  ImageActionOverlay.swift
//  InstaGridswift
//

import SwiftUI

struct ImageActionOverlay: View {
    let onHide: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background - tap to dismiss
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .onTapGesture {
                        HapticService.impact(.light)
                        onDismiss()
                    }

                // Action buttons container
                VStack(spacing: 16) {
                    HStack(spacing: 24) {
                        // Hide button
                        Button {
                            HapticService.impact(.medium)
                            onHide()
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.gradient)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: .orange.opacity(0.4), radius: 6, y: 3)

                                    Image(systemName: "eye.slash.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                Text("Hide")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(ActionButtonStyle())

                        // Crop button
                        Button {
                            HapticService.impact(.medium)
                            onEdit()
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.gradient)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: .blue.opacity(0.4), radius: 6, y: 3)

                                    Image(systemName: "crop.rotate")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                Text("Crop")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(ActionButtonStyle())
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

private struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.gray
        ImageActionOverlay(
            onHide: { print("Hide tapped") },
            onEdit: { print("Edit tapped") },
            onDismiss: { print("Dismiss") }
        )
    }
    .frame(width: 200, height: 250)
}
