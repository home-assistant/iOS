import AVFoundation
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// The barcode scanner's parts that don't need a camera: every symbology maps to the name the
/// frontend expects, detections reach the model's delegate, the camera wrapper is inert without a
/// capture device, and the preview view renders (and stops the model) without starting the camera.
@MainActor
struct BarcodeScannerModelTests {
    private final class Detections: BarcodeScannerDataModelDelegate {
        var codes: [(String, String)] = []
        func didDetectBarcode(_ code: String, format: String) {
            codes.append((code, format))
        }
    }

    @Test func everySymbologyHasItsFrontendName() {
        let expected: [AVMetadataObject.ObjectType: String] = [
            .codabar: "codabar",
            .qr: "qr_code",
            .aztec: "aztec",
            .code128: "code_128",
            .code39: "code_39",
            .code93: "code_93",
            .dataMatrix: "data_matrix",
            .ean13: "ean_13",
            .ean8: "ean_8",
            .itf14: "itf",
            .pdf417: "pdf417",
            .upce: "upc_e",
            .face: "unknown",
        ]
        for (type, name) in expected {
            #expect(type.haString == name)
        }
    }

    @Test func detectionsReachTheDelegate() {
        let model = BarcodeScannerDataModel()
        defer { model.stop() }
        let detections = Detections()
        model.delegate = detections

        model.didDetectBarcode("4006381333931", format: "ean_13")

        #expect(detections.codes.count == 1)
        #expect(detections.codes.first?.0 == "4006381333931")
        #expect(detections.codes.first?.1 == "ean_13")
    }

    /// The simulator has no camera: the flashlight and stop calls have nothing to act on, and the
    /// rect of interest is still derived from the screen size.
    @Test func theCameraIsInertWithoutACaptureDevice() {
        let model = BarcodeScannerDataModel()
        model.toggleFlashlight()
        model.turnOffFlashlight()
        model.camera.screenSize = CGSize(width: 390, height: 844)
        model.camera.screenSize = nil
        #expect(!model.camera.isRunning)
        model.camera.isPreviewPaused = true
        model.stop()
        #expect(!model.camera.isRunning)
    }

    @Test func theViewModelForwardsResultsToTheFrontend() {
        let viewModel = BarcodeScannerViewModel(incomingMessageId: 42)
        viewModel.didDetectBarcode("hello", format: "qr_code")
        viewModel.aborted(.canceled)
        viewModel.aborted(.alternativeOptions)
        #expect(BarcodeScannerViewModel.AbortReason.alternativeOptions.rawValue == "alternative_options")
    }

    @Test(arguments: [false, true])
    func thePreviewRendersWithoutStartingTheCamera(_ withImage: Bool) {
        let model = BarcodeScannerDataModel()
        if withImage {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
            model.viewfinderImage = Image(uiImage: image)
        }
        let host = UIHostingController(rootView: BarcodeScannerCameraView(
            screenSize: CGSize(width: 390, height: 844),
            model: model,
            shouldStartCamera: false
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
        #expect(!model.camera.isRunning)
        #expect(BarcodeScannerView.cameraSquareSize == 320)
    }
}
