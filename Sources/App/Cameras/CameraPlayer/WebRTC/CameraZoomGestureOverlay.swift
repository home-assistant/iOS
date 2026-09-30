import SwiftUI

#if os(macOS)
struct CameraZoomGestureOverlay: NSViewRepresentable {
    var onPinchBegan: (CGPoint) -> Void
    var onPinchChanged: (CGFloat, CGPoint) -> Void
    var onPinchEnded: () -> Void
    var onDoubleTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = GestureView()

        let pinch = NSMagnificationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        let doubleTap = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfClicksRequired = 2
        // Clicks still reach the player underneath as they happen, so a single one toggles its
        // controls without waiting to see whether a second follows.
        doubleTap.delaysPrimaryMouseButtonEvents = false
        doubleTap.delegate = context.coordinator
        view.addGestureRecognizer(doubleTap)

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var parent: CameraZoomGestureOverlay

        init(parent: CameraZoomGestureOverlay) {
            self.parent = parent
        }

        @objc
        func handlePinch(_ recognizer: NSMagnificationGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            switch recognizer.state {
            case .began:
                parent.onPinchBegan(location)
            case .changed:
                // A magnification counts from zero where a pinch's scale counts from one.
                parent.onPinchChanged(1 + recognizer.magnification, location)
            case .ended, .cancelled, .failed:
                parent.onPinchEnded()
            default:
                break
            }
        }

        @objc
        func handleDoubleTap(_ recognizer: NSClickGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            parent.onDoubleTap(location)
        }

        func gestureRecognizer(
            _ gestureRecognizer: NSGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
        ) -> Bool {
            true
        }
    }

    /// Measures from the top left, as SwiftUI and the zoom arithmetic do; AppKit starts at the bottom.
    private final class GestureView: NSView {
        override var isFlipped: Bool { true }
    }
}
#else
struct CameraZoomGestureOverlay: UIViewRepresentable {
    var onPinchBegan: (CGPoint) -> Void
    var onPinchChanged: (CGFloat, CGPoint) -> Void
    var onPinchEnded: () -> Void
    var onDoubleTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator
        view.addGestureRecognizer(doubleTap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CameraZoomGestureOverlay

        init(parent: CameraZoomGestureOverlay) {
            self.parent = parent
        }

        @objc
        func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            switch recognizer.state {
            case .began:
                parent.onPinchBegan(location)
            case .changed:
                parent.onPinchChanged(recognizer.scale, location)
            case .ended, .cancelled, .failed:
                parent.onPinchEnded()
            default:
                break
            }
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .recognized, let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            parent.onDoubleTap(location)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif
