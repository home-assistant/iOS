#if !os(watchOS)
import AVFoundation
import SwiftUI
import UIKit

/// A live camera feed that reports the barcodes it sees. The capture half of the frontend's
/// `ha-qr-scanner`, which does the same job with `getUserMedia` and a `<video>` element.
///
/// AVFoundation finds and decodes the codes itself, so there is no decoding library here — the
/// frontend needs `qr-scanner` because the web platform has no equivalent.
///
/// Nothing starts until this appears on screen, and everything stops when it leaves: a capture
/// session left running holds the camera and the indicator stays lit.
public struct HACameraPreview: UIViewRepresentable {
    private let types: [AVMetadataObject.ObjectType]
    private let onScan: (String) -> Void

    /// - Parameter types: Which symbologies to look for. QR only by default, matching the frontend.
    public init(
        types: [AVMetadataObject.ObjectType] = [.qr],
        onScan: @escaping (String) -> Void
    ) {
        self.types = types
        self.onScan = onScan
    }

    public func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.start(on: view, types: types)
        return view
    }

    public func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onScan = onScan
    }

    public static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    /// A view backed by the preview layer itself, rather than one holding a sublayer: this way the
    /// layer resizes with the view and there is no manual frame bookkeeping on rotation.
    public final class PreviewView: UIView {
        override public class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        /// Optional only to keep a force-cast out of the code — `layerClass` above guarantees the
        /// type, so this never returns `nil` in practice.
        var previewLayer: AVCaptureVideoPreviewLayer? {
            layer as? AVCaptureVideoPreviewLayer
        }
    }

    public final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: (String) -> Void
        private let session = AVCaptureSession()
        /// Configuring and running a session blocks; keeping it off the main queue is what stops
        /// the first frame from stuttering the UI.
        private let queue = DispatchQueue(label: "HACameraPreview.session")

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func start(on view: PreviewView, types: [AVMetadataObject.ObjectType]) {
            view.previewLayer?.session = session
            view.previewLayer?.videoGravity = .resizeAspectFill

            // No camera at all — the simulator, or a Mac without one. The caller decides what to
            // show; here it just means there is nothing to start.
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }
            queue.async { [session] in
                session.beginConfiguration()
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                let output = AVCaptureMetadataOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    output.setMetadataObjectsDelegate(self, queue: .main)
                    // Assignable only once the output is attached, since the available types
                    // depend on the session it belongs to.
                    output.metadataObjectTypes = types.filter(output.availableMetadataObjectTypes.contains)
                }
                session.commitConfiguration()
                session.startRunning()
            }
        }

        func stop() {
            queue.async { [session] in
                if session.isRunning {
                    session.stopRunning()
                }
            }
        }

        public func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else {
                return
            }
            onScan(value)
        }
    }
}

extension HACameraPreview: FrontendComponent {
    public static var frontendComponentName: String { "ha-qr-scanner" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
