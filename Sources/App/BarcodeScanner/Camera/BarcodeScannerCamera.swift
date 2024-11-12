import AVFoundation
import CoreImage
import Shared
import UIKit

class BarcodeScannerCamera: NSObject {
    private let captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let metadataOutput = AVCaptureMetadataOutput()
    private var sessionQueue: DispatchQueue!
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var allBackCaptureDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
            ],
            mediaType: .video,
            position: .back
        ).devices
    }

    private var availableCaptureDevices: [AVCaptureDevice] {
        allBackCaptureDevices
            .filter(\.isConnected)
            .filter({ !$0.isSuspended })
    }

    private var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice else { return }
            Current.Log.info("Using capture device: \(captureDevice.localizedName)")
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
        }
    }

    /// Last time a barcode was detected
    private var lastDetection: Date?

    var barcodeFound: ((_ code: String, _ format: String) -> Void)?
    var isRunning: Bool {
        captureSession.isRunning
    }

    private var addToPhotoStream: ((AVCapturePhoto) -> Void)?

    private var addToPreviewStream: ((CIImage) -> Void)?

    var isPreviewPaused = false

    lazy var previewStream: AsyncStream<CIImage> = AsyncStream { continuation in
        addToPreviewStream = { ciImage in
            if !self.isPreviewPaused {
                continuation.yield(ciImage)
            }
        }
    }

    override init() {
        super.init()
        self.sessionQueue = DispatchQueue(label: "session queue")
        self.captureDevice = availableCaptureDevices.first ?? AVCaptureDevice.default(for: .video)

        feedbackGenerator.prepare()
    }

    private func configureCaptureSession(completionHandler: (_ success: Bool) -> Void) {
        var success = false

        captureSession.beginConfiguration()

        defer {
            self.captureSession.commitConfiguration()
            completionHandler(success)
        }

        guard
            let captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            Current.Log.error("Failed to obtain video input.")
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))

        guard captureSession.canAddInput(deviceInput) else {
            Current.Log.error("Unable to add device input to capture session.")
            return
        }
        guard captureSession.canAddOutput(videoOutput) else {
            Current.Log.error("Unable to add video output to capture session.")
            return
        }

        guard captureSession.canAddOutput(metadataOutput) else {
            Current.Log.error("Unable to add metadata output to capture session.")
            return
        }

        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

        var metadataObjectTypes: [AVMetadataObject.ObjectType] = [
            .qr,
            .aztec,
            .code128,
            .code39,
            .code93,
            .dataMatrix,
            .ean13,
            .ean8,
            .itf14,
            .pdf417,
            .upce,
        ]

        if #available(iOS 15.4, *) {
            metadataObjectTypes.append(.codabar)
        }

        metadataOutput.metadataObjectTypes = metadataObjectTypes

        self.deviceInput = deviceInput
        self.videoOutput = videoOutput

        isCaptureSessionConfigured = true

        success = true
    }

    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Current.Log.info("Camera access authorized.")
            return true
        case .notDetermined:
            Current.Log.info("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return status
        case .denied:
            Current.Log.info("Camera access denied.")
            return false
        case .restricted:
            Current.Log.info("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }

    private func deviceInputFor(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch {
            Current.Log.error("Error getting capture device input: \(error.localizedDescription)")
            return nil
        }
    }

    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) {
        guard isCaptureSessionConfigured else { return }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }

        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput), captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
                configureFocus(for: deviceInput.device)
            }
        }
    }

    private func configureFocus(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // Set focus point to center
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) // Center of the screen
            }

            device.unlockForConfiguration()
        } catch {
            Current.Log.error("Error setting  barcode scanner camera focus: \(error)")
        }
    }

    func start() async {
        guard !captureSession.isRunning else { return }

        let authorized = await checkAuthorization()
        guard authorized else {
            Current.Log.error("Camera access was not authorized.")
            return
        }

        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    captureSession.startRunning()
                }
            }
            return
        }

        sessionQueue.async { [self] in
            configureCaptureSession { success in
                guard success else { return }
                self.captureSession.startRunning()
            }
        }
    }

    func stop() {
        guard isCaptureSessionConfigured else { return }

        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }

    func toggleFlashlight() {
        guard let captureDevice, captureDevice.hasTorch else { return }

        do {
            try captureDevice.lockForConfiguration()

            if captureDevice.torchMode == .off {
                try captureDevice.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                captureDevice.torchMode = .off
            }

            captureDevice.unlockForConfiguration()
        } catch {
            Current.Log.info("Flashlight could not be used: \(error)")
        }
    }

    func turnOffFlashlight() {
        guard let captureDevice, captureDevice.hasTorch else { return }

        do {
            try captureDevice.lockForConfiguration()
            captureDevice.torchMode = .off
            captureDevice.unlockForConfiguration()
        } catch {
            Current.Log.info("Flashlight could not be turned off: \(error)")
        }
    }

    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }

    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait: return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft: return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        default: return nil
        }
    }
}

extension BarcodeScannerCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

        if connection.isVideoOrientationSupported,
           let videoOrientation = videoOrientationFor(deviceOrientation) {
            connection.videoOrientation = videoOrientation
        }

        addToPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
}

extension BarcodeScannerCamera: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Avoid several detections if user keeps camera pointing to the same barcode
        if let lastDetection {
            guard Date().timeIntervalSince(lastDetection) > 1.5 else { return }
        }

        if let metadataObject = metadataObjects.first {
            let format = metadataObject.type.haString
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            feedbackGenerator.notificationOccurred(.success)
            lastDetection = Date()
            barcodeFound?(stringValue, format)
        }
    }
}

private extension UIScreen {
    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0, point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0, point.y != 0 {
            return .landscapeRight
        } else if point.x != 0, point.y == 0 {
            return .landscapeLeft
        } else {
            return .unknown
        }
    }
}

private extension AVMetadataObject.ObjectType {
    var haString: String {
        if #available(iOS 15.4, *), self == .codabar {
            return "codabar"
        }

        switch self {
        case .qr: return "qr_code"
        case .aztec: return "aztec"
        case .code128: return "code_128"
        case .code39: return "code_39"
        case .code93: return "code_93"
        case .dataMatrix: return "data_matrix"
        case .ean13: return "ean_13"
        case .ean8: return "ean_8"
        case .itf14: return "itf"
        case .pdf417: return "pdf417"
        case .upce: return "upc_e"
        default: return "unknown"
        }
    }
}
