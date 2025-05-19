import AVFoundation
import os.log
import SwiftUI

protocol BarcodeScannerDataModelDelegate: AnyObject {
    func didDetectBarcode(_ code: String, format: String)
}

final class BarcodeScannerDataModel: ObservableObject {
    let camera = BarcodeScannerCamera()

    @Published var viewfinderImage: Image?
    weak var delegate: BarcodeScannerDataModelDelegate?

    private var handleCameraPreviewsTask: Task<Void, Never>?
    private var viewFinderImageTask: Task<Void, Never>?

    init() {
        camera.delegate = self
        self.handleCameraPreviewsTask = Task {
            await handleCameraPreviews()
        }
    }

    func stop() {
        handleCameraPreviewsTask?.cancel()
        viewFinderImageTask?.cancel()
    }

    func handleCameraPreviews() async {
        guard let previewStream = camera.previewStream else {
            return
        }
        let imageStream = previewStream.map(\.image)

        for await image in imageStream {
            await MainActor.run {
                viewfinderImage = image
            }
        }
    }

    func toggleFlashlight() {
        camera.toggleFlashlight()
    }

    func turnOffFlashlight() {
        camera.turnOffFlashlight()
    }
}

extension BarcodeScannerDataModel: BarcodeScannerCameraDelegate {
    func didDetectBarcode(_ code: String, format: String) {
        delegate?.didDetectBarcode(code, format: format)
    }
}

private extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
