//
//  DragGestureView.swift
//  InstaGridswift
//

import SwiftUI
import UIKit

/// A UIViewRepresentable that provides smooth drag and drop with proper ScrollView coexistence
struct DragGestureView<Content: View>: UIViewRepresentable {
    let content: Content
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    init(
        onDragStarted: @escaping () -> Void = {},
        onDragChanged: @escaping (CGSize) -> Void = { _ in },
        onDragEnded: @escaping (CGSize) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onDragStarted = onDragStarted
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    func makeUIView(context: Context) -> DragHostView {
        let hostView = DragHostView()
        let hostController = UIHostingController(rootView: content)
        hostController.view.backgroundColor = .clear

        hostView.addSubview(hostController.view)
        hostController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostController.view.topAnchor.constraint(equalTo: hostView.topAnchor),
            hostController.view.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            hostController.view.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            hostController.view.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])

        // Store reference to hosting controller
        hostView.hostController = hostController

        // Set up drag gesture
        let dragGesture = DragGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDrag(_:))
        )
        dragGesture.dragDelegate = context.coordinator
        hostView.addGestureRecognizer(dragGesture)

        return hostView
    }

    func updateUIView(_ uiView: DragHostView, context: Context) {
        // Update the SwiftUI content
        context.coordinator.onDragStarted = onDragStarted
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded

        if let hostController = uiView.hostController as? UIHostingController<Content> {
            hostController.rootView = content
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDragStarted: onDragStarted,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
    }

    class Coordinator: NSObject, DragGestureDelegate {
        var onDragStarted: () -> Void
        var onDragChanged: (CGSize) -> Void
        var onDragEnded: (CGSize) -> Void

        private var initialLocation: CGPoint = .zero

        init(
            onDragStarted: @escaping () -> Void,
            onDragChanged: @escaping (CGSize) -> Void,
            onDragEnded: @escaping (CGSize) -> Void
        ) {
            self.onDragStarted = onDragStarted
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
        }

        @objc func handleDrag(_ gesture: DragGestureRecognizer) {
            let location = gesture.location(in: gesture.view)

            switch gesture.state {
            case .began:
                initialLocation = location
                onDragStarted()

            case .changed:
                let translation = CGSize(
                    width: location.x - initialLocation.x,
                    height: location.y - initialLocation.y
                )
                onDragChanged(translation)

            case .ended, .cancelled:
                let translation = CGSize(
                    width: location.x - initialLocation.x,
                    height: location.y - initialLocation.y
                )
                onDragEnded(translation)

            default:
                break
            }
        }

        // MARK: - DragGestureDelegate

        func shouldBeginDrag(at location: CGPoint, in view: UIView) -> Bool {
            return true
        }

        func shouldRecognizeSimultaneouslyWith(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow simultaneous recognition with scroll view gestures
            return otherGestureRecognizer.view is UIScrollView
        }

        func shouldRequireFailureOf(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }

        func shouldBeRequiredToFailBy(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
    }
}

// MARK: - Supporting Classes

class DragHostView: UIView {
    var hostController: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
}

protocol DragGestureDelegate: AnyObject {
    func shouldBeginDrag(at location: CGPoint, in view: UIView) -> Bool
    func shouldRecognizeSimultaneouslyWith(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func shouldRequireFailureOf(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func shouldBeRequiredToFailBy(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool
}

class DragGestureRecognizer: UILongPressGestureRecognizer, UIGestureRecognizerDelegate {
    weak var dragDelegate: DragGestureDelegate?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)

        // Configure for smooth dragging
        self.minimumPressDuration = 0.3
        self.allowableMovement = 10.0
        self.delegate = self

        // Key: Set the cancel touches in view to false
        // This allows the gesture to work alongside other gestures
        self.cancelsTouchesInView = false
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return dragDelegate?.shouldRecognizeSimultaneouslyWith(otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return dragDelegate?.shouldRequireFailureOf(otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return dragDelegate?.shouldBeRequiredToFailBy(otherGestureRecognizer) ?? false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        return dragDelegate?.shouldBeginDrag(at: location, in: gestureRecognizer.view!) ?? true
    }
}
