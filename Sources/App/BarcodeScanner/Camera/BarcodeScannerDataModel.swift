import AVFoundation
import os.log
import SwiftUI

final class BarcodeScannerDataModel: ObservableObject {
    let camera = BarcodeScannerCamera()

    @Published var viewfinderImage: Image?
    init() {
        Task {
            await handleCameraPreviews()
        }
    }

    func handleCameraPreviews() async {
        let imageStream = camera.previewStream
            .map(\.image)

        for await image in imageStream {
            Task { @MainActor in
                viewfinderImage = image
            }
        }
    }

    func toggleFlashlight() {
        camera.toggleFlashlight()
    }
}

private extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
