import SwiftUI
import UIKit

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
