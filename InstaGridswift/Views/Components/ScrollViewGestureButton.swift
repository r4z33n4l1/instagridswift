//
//  ScrollViewGestureButton.swift
//  InstaGridswift
//
//  A button-based gesture handler that works inside ScrollView without blocking scroll.
//  Based on the technique from: https://danielsaidi.com/blog/2022/11/16/using-complex-gestures-in-a-scroll-view
//

import SwiftUI

/// A button wrapper that detects long press and drag gestures without blocking ScrollView scrolling.
/// Uses ButtonStyle to detect press states, which doesn't interfere with scroll gestures.
struct ScrollViewGestureButton<Label: View>: View {
    let longPressDuration: TimeInterval
    let onLongPress: () -> Void
    let onDragStart: (CGPoint) -> Void
    let onDragChange: (CGSize) -> Void
    let onDragEnd: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressing = false
    @State private var longPressDate: Date?
    @State private var longPressTriggered = false
    @State private var dragStarted = false
    @State private var dragStartLocation: CGPoint = .zero

    init(
        longPressDuration: TimeInterval = 0.5,
        onLongPress: @escaping () -> Void = {},
        onDragStart: @escaping (CGPoint) -> Void = { _ in },
        onDragChange: @escaping (CGSize) -> Void = { _ in },
        onDragEnd: @escaping () -> Void = {},
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.longPressDuration = longPressDuration
        self.onLongPress = onLongPress
        self.onDragStart = onDragStart
        self.onDragChange = onDragChange
        self.onDragEnd = onDragEnd
        self.label = label
    }

    var body: some View {
        Button(action: {}) {
            label()
        }
        .buttonStyle(
            ScrollViewGestureButtonStyle(
                isPressing: $isPressing,
                onPressStart: handlePressStart,
                onPressEnd: handlePressEnd
            )
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onChanged { value in
                    // Cancel long press if we start dragging
                    longPressDate = nil

                    if !dragStarted {
                        dragStarted = true
                        dragStartLocation = value.startLocation
                        onDragStart(value.startLocation)
                    }
                    onDragChange(value.translation)
                }
                .onEnded { _ in
                    if dragStarted {
                        onDragEnd()
                    }
                    dragStarted = false
                    dragStartLocation = .zero
                }
        )
    }

    private func handlePressStart() {
        longPressTriggered = false
        dragStarted = false
        let date = Date()
        longPressDate = date

        // Schedule long press trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration) {
            // Only trigger if this is still the active press and we haven't started dragging
            guard longPressDate == date, !dragStarted else { return }
            longPressTriggered = true
            onLongPress()
        }
    }

    private func handlePressEnd() {
        longPressDate = nil

        // If we were dragging, end the drag
        if dragStarted {
            onDragEnd()
            dragStarted = false
        }
    }
}

/// A button style that detects press states and provides visual feedback without interfering with ScrollView.
struct ScrollViewGestureButtonStyle: ButtonStyle {
    @Binding var isPressing: Bool
    let onPressStart: () -> Void
    let onPressEnd: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Visual feedback during press - subtle scale and dim
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                isPressing = isPressed
                if isPressed {
                    onPressStart()
                } else {
                    onPressEnd()
                }
            }
    }
}
