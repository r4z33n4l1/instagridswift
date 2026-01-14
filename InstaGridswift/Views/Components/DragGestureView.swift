//
//  DragGestureView.swift
//  InstaGridswift
//

import SwiftUI
import UIKit

/// Configuration for context menu actions
struct ContextMenuConfig {
    let onShare: (() -> Void)?
    let onHide: () -> Void
    let onEditCrop: () -> Void
    let onDelete: () -> Void
    let previewProvider: () -> UIViewController?

    init(
        onShare: (() -> Void)? = nil,
        onHide: @escaping () -> Void,
        onEditCrop: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        previewProvider: @escaping () -> UIViewController? = { nil }
    ) {
        self.onShare = onShare
        self.onHide = onHide
        self.onEditCrop = onEditCrop
        self.onDelete = onDelete
        self.previewProvider = previewProvider
    }
}

/// A UIViewRepresentable that provides smooth drag and drop with proper ScrollView coexistence
/// and native iOS context menu support
struct DragGestureView<Content: View>: UIViewRepresentable {
    let content: Content
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let contextMenuConfig: ContextMenuConfig?

    init(
        onDragStarted: @escaping () -> Void = {},
        onDragChanged: @escaping (CGSize) -> Void = { _ in },
        onDragEnded: @escaping (CGSize) -> Void = { _ in },
        contextMenuConfig: ContextMenuConfig? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onDragStarted = onDragStarted
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.contextMenuConfig = contextMenuConfig
    }

    func makeUIView(context: Context) -> DragHostView {
        let hostView = DragHostView()
        hostView.backgroundColor = .clear
        hostView.isOpaque = false

        let hostController = UIHostingController(rootView: content)
        hostController.view.backgroundColor = .clear
        hostController.view.isOpaque = false

        // Remove any system background
        if #available(iOS 16.0, *) {
            hostController.sizingOptions = .intrinsicContentSize
        }

        hostView.addSubview(hostController.view)
        hostController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostController.view.topAnchor.constraint(equalTo: hostView.topAnchor),
            hostController.view.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            hostController.view.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            hostController.view.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])

        hostView.hostController = hostController

        // Set up drag gesture with higher priority
        let dragGesture = DragGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDrag(_:))
        )
        dragGesture.dragDelegate = context.coordinator
        context.coordinator.dragGesture = dragGesture
        context.coordinator.hostView = hostView
        hostView.addGestureRecognizer(dragGesture)

        // Set up context menu if configured
        if contextMenuConfig != nil {
            let contextMenuInteraction = UIContextMenuInteraction(delegate: context.coordinator)
            hostView.addInteraction(contextMenuInteraction)
            context.coordinator.contextMenuInteraction = contextMenuInteraction
        }

        return hostView
    }

    func updateUIView(_ uiView: DragHostView, context: Context) {
        context.coordinator.onDragStarted = onDragStarted
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded
        context.coordinator.contextMenuConfig = contextMenuConfig

        if let hostController = uiView.hostController as? UIHostingController<Content> {
            hostController.rootView = content
            hostController.view.backgroundColor = .clear
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDragStarted: onDragStarted,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded,
            contextMenuConfig: contextMenuConfig
        )
    }

    class Coordinator: NSObject, DragGestureDelegate, UIContextMenuInteractionDelegate {
        var onDragStarted: () -> Void
        var onDragChanged: (CGSize) -> Void
        var onDragEnded: (CGSize) -> Void
        var contextMenuConfig: ContextMenuConfig?

        weak var dragGesture: DragGestureRecognizer?
        weak var contextMenuInteraction: UIContextMenuInteraction?
        weak var hostView: DragHostView?

        private var initialLocationInWindow: CGPoint = .zero
        private var isDragging: Bool = false
        private var isContextMenuActive: Bool = false  // True when context menu is preparing or visible
        private var hasMovedBeyondThreshold: Bool = false  // Track if user moved enough to drag
        private var gestureStartTime: Date?
        private let dragThreshold: CGFloat = 8  // Movement threshold to switch from menu to drag

        private weak var parentScrollView: UIScrollView?
        private var autoScrollTimer: Timer?
        private let edgeScrollThreshold: CGFloat = 60
        private let autoScrollSpeed: CGFloat = 8

        init(
            onDragStarted: @escaping () -> Void,
            onDragChanged: @escaping (CGSize) -> Void,
            onDragEnded: @escaping (CGSize) -> Void,
            contextMenuConfig: ContextMenuConfig?
        ) {
            self.onDragStarted = onDragStarted
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
            self.contextMenuConfig = contextMenuConfig
        }

        @objc func handleDrag(_ gesture: DragGestureRecognizer) {
            guard let view = gesture.view,
                  let window = view.window else { return }

            let locationInWindow = gesture.location(in: window)

            switch gesture.state {
            case .began:
                initialLocationInWindow = locationInWindow
                isDragging = false
                hasMovedBeyondThreshold = false
                gestureStartTime = Date()
                parentScrollView = findScrollView(from: view)

            case .changed:
                let translation = CGSize(
                    width: locationInWindow.x - initialLocationInWindow.x,
                    height: locationInWindow.y - initialLocationInWindow.y
                )

                let distance = sqrt(translation.width * translation.width + translation.height * translation.height)

                if !isDragging && distance > dragThreshold {
                    hasMovedBeyondThreshold = true
                    isDragging = true

                    // Dismiss context menu if it's preparing or showing
                    if isContextMenuActive, let interaction = contextMenuInteraction {
                        // Dismiss asynchronously to avoid gesture conflicts
                        DispatchQueue.main.async {
                            interaction.dismissMenu()
                        }
                        isContextMenuActive = false
                    }

                    parentScrollView?.isScrollEnabled = false
                    HapticService.impact(.medium)
                    onDragStarted()
                }

                if isDragging {
                    onDragChanged(translation)
                    handleEdgeAutoScroll(gesture: gesture)
                }

            case .ended, .cancelled:
                if isDragging {
                    let translation = CGSize(
                        width: locationInWindow.x - initialLocationInWindow.x,
                        height: locationInWindow.y - initialLocationInWindow.y
                    )
                    onDragEnded(translation)
                }

                parentScrollView?.isScrollEnabled = true
                parentScrollView = nil
                stopAutoScroll()
                isDragging = false
                hasMovedBeyondThreshold = false
                gestureStartTime = nil

            default:
                break
            }
        }

        private func findScrollView(from view: UIView) -> UIScrollView? {
            var current: UIView? = view.superview
            while let parent = current {
                if let scrollView = parent as? UIScrollView {
                    return scrollView
                }
                current = parent.superview
            }
            return nil
        }

        private func handleEdgeAutoScroll(gesture: UIGestureRecognizer) {
            guard let scrollView = parentScrollView,
                  let window = gesture.view?.window else {
                stopAutoScroll()
                return
            }

            let locationInWindow = gesture.location(in: window)
            let scrollViewFrameInWindow = scrollView.convert(scrollView.bounds, to: window)

            let distanceFromTop = locationInWindow.y - scrollViewFrameInWindow.minY
            let distanceFromBottom = scrollViewFrameInWindow.maxY - locationInWindow.y

            var scrollDirection: CGFloat = 0

            if distanceFromTop < edgeScrollThreshold && scrollView.contentOffset.y > 0 {
                scrollDirection = -1
            } else if distanceFromBottom < edgeScrollThreshold {
                let maxOffsetY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
                if scrollView.contentOffset.y < maxOffsetY {
                    scrollDirection = 1
                }
            }

            if scrollDirection != 0 {
                startAutoScroll(direction: scrollDirection, gesture: gesture)
            } else {
                stopAutoScroll()
            }
        }

        private func startAutoScroll(direction: CGFloat, gesture: UIGestureRecognizer) {
            if autoScrollTimer != nil { return }

            autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                guard let self = self,
                      let scrollView = self.parentScrollView,
                      let window = gesture.view?.window else {
                    self?.stopAutoScroll()
                    return
                }

                var newOffset = scrollView.contentOffset
                newOffset.y += direction * self.autoScrollSpeed

                let minY: CGFloat = -scrollView.contentInset.top
                let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
                newOffset.y = min(max(newOffset.y, minY), maxY)

                scrollView.contentOffset = newOffset

                if gesture.state == .changed {
                    let locationInWindow = gesture.location(in: window)
                    let translation = CGSize(
                        width: locationInWindow.x - self.initialLocationInWindow.x,
                        height: locationInWindow.y - self.initialLocationInWindow.y
                    )
                    self.onDragChanged(translation)
                }
            }
        }

        private func stopAutoScroll() {
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
        }

        // MARK: - DragGestureDelegate

        func shouldBeginDrag(at location: CGPoint, in view: UIView) -> Bool {
            return true
        }

        func shouldRecognizeSimultaneouslyWith(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow context menu's gestures to work simultaneously until we start dragging
            let gestureType = String(describing: type(of: otherGestureRecognizer))
            if gestureType.contains("ContextMenu") || gestureType.contains("UILongPress") {
                return !isDragging
            }
            return false
        }

        func shouldRequireFailureOf(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }

        func shouldBeRequiredToFailBy(_ otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is UIPanGestureRecognizer,
               otherGestureRecognizer.view is UIScrollView {
                return true
            }
            return false
        }

        // MARK: - UIContextMenuInteractionDelegate

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            // Don't show context menu if already dragging or moved beyond threshold
            guard !isDragging, !hasMovedBeyondThreshold, let config = contextMenuConfig else { return nil }

            // Mark that context menu is starting to prepare
            isContextMenuActive = true

            return UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: config.previewProvider,
                actionProvider: { _ in
                    var actions: [UIMenuElement] = []

                    // Share action (if available)
                    if let onShare = config.onShare {
                        actions.append(UIAction(
                            title: "Share",
                            image: UIImage(systemName: "square.and.arrow.up")
                        ) { _ in onShare() })
                    }

                    // Edit Crop
                    actions.append(UIAction(
                        title: "Crop",
                        image: UIImage(systemName: "crop")
                    ) { _ in config.onEditCrop() })

                    // Hide
                    actions.append(UIAction(
                        title: "Hide",
                        image: UIImage(systemName: "eye.slash")
                    ) { _ in config.onHide() })

                    // Delete (destructive)
                    actions.append(UIAction(
                        title: "Delete",
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive
                    ) { _ in config.onDelete() })

                    return UIMenu(children: actions)
                }
            )
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willDisplayMenuFor configuration: UIContextMenuConfiguration,
            animator: (any UIContextMenuInteractionAnimating)?
        ) {
            isContextMenuActive = true
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willEndFor configuration: UIContextMenuConfiguration,
            animator: (any UIContextMenuInteractionAnimating)?
        ) {
            isContextMenuActive = false
        }

        // Called when the preview is about to be shown (during wind-up animation)
        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
        ) -> UITargetedPreview? {
            // If we started dragging during preparation, dismiss and return nil
            if isDragging || hasMovedBeyondThreshold {
                DispatchQueue.main.async {
                    interaction.dismissMenu()
                }
                return nil
            }
            // Return nil to use the default view as preview source
            return nil
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
            animator: any UIContextMenuInteractionCommitAnimating
        ) {
            // Handle tap on preview if needed
        }
    }
}

// MARK: - Supporting Classes

class DragHostView: UIView {
    var hostController: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure no system backgrounds sneak in
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

        self.minimumPressDuration = 0.2  // Start tracking early to catch movement before context menu
        self.allowableMovement = .greatestFiniteMagnitude
        self.delegate = self
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
