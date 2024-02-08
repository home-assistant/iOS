import SwiftUI

struct QRScannerCameraView: View {
    @StateObject private var model: QRScannerDataModel
    private let shouldStartCamera: Bool

    init(model: QRScannerDataModel, shouldStartCamera: Bool = true) {
        self._model = .init(wrappedValue: model)
        self.shouldStartCamera = shouldStartCamera
    }

    var body: some View {
        GeometryReader { geometry in
            if let image = $model.viewfinderImage.wrappedValue {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .task {
            if shouldStartCamera {
                await model.camera.start()
            }
        }
    }
}
