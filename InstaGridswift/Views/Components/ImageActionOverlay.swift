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
        // Use Color as background with contentShape for tap detection
        Color.black.opacity(0.6)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticService.impact(.light)
                onDismiss()
            }
            .overlay {
                // Action buttons container - buttons will intercept taps
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
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .orange.opacity(0.4), radius: 6, y: 3)

                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            Text("Hide")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .contentShape(Rectangle())
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
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .blue.opacity(0.4), radius: 6, y: 3)

                                Image(systemName: "crop.rotate")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            Text("Crop")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ActionButtonStyle())
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
    ImageActionOverlay(
        onHide: { print("Hide tapped") },
        onEdit: { print("Edit tapped") },
        onDismiss: { print("Dismiss") }
    )
    .frame(width: 200, height: 250)
}
