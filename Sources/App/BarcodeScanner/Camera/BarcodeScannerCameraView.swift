import SwiftUI

struct BarcodeScannerCameraView: View {
    @StateObject private var model: BarcodeScannerDataModel
    private let shouldStartCamera: Bool
    private let screenSize: CGSize

    init(screenSize: CGSize, model: BarcodeScannerDataModel, shouldStartCamera: Bool = true) {
        self._model = .init(wrappedValue: model)
        self.shouldStartCamera = shouldStartCamera
        self.screenSize = screenSize

        // If camera shouldn't be started, no need to forward screen size for rect of interest
        if shouldStartCamera {
            model.camera.screenSize = screenSize
        }
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
        .onDisappear {
            model.stop()
        }
    }
}
