#if os(iOS) && !targetEnvironment(macCatalyst)
import RoomPlan
import SwiftUI

struct RoomPlanCaptureView: UIViewRepresentable {
    @Binding var isScanning: Bool
    let onCaptured: (CapturedRoom) -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCaptured: onCaptured, onError: onError)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = context.coordinator
        context.coordinator.captureView = view
        context.coordinator.updateScanning(isScanning)
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        context.coordinator.updateScanning(isScanning)
    }

    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        coordinator.stopIfNeeded()
        uiView.delegate = nil
    }

    @objc(HASpatialScannerRoomCaptureCoordinator)
    final class Coordinator: NSObject, RoomCaptureViewDelegate {
        weak var captureView: RoomCaptureView?

        private let onCaptured: (CapturedRoom) -> Void
        private let onError: (Error) -> Void
        private var isRunning = false

        init(
            onCaptured: @escaping (CapturedRoom) -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.onCaptured = onCaptured
            self.onError = onError
        }

        required init?(coder _: NSCoder) {
            nil
        }

        func encode(with _: NSCoder) {
            // The delegate is owned for the lifetime of the SwiftUI representable and is never archived.
        }

        func updateScanning(_ shouldScan: Bool) {
            guard let captureView else { return }
            if shouldScan, !isRunning {
                let configuration = RoomCaptureSession.Configuration()
                captureView.captureSession.run(configuration: configuration)
                isRunning = true
            } else if !shouldScan, isRunning {
                captureView.captureSession.stop()
                isRunning = false
            }
        }

        func stopIfNeeded() {
            guard isRunning else { return }
            captureView?.captureSession.stop()
            isRunning = false
        }

        func captureView(
            shouldPresent _: CapturedRoomData,
            error: Error?
        ) -> Bool {
            if let error {
                onError(error)
                return false
            }
            return true
        }

        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            if let error {
                onError(error)
            } else {
                onCaptured(processedResult)
            }
        }
    }
}

#Preview {
    RoomPlanCaptureView(
        isScanning: .constant(false),
        onCaptured: { _ in },
        onError: { _ in }
    )
}
#endif
