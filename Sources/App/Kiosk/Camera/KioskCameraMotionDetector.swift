import AVFoundation
import Combine
import CoreImage
import Shared
import UIKit

// MARK: - Kiosk Camera Motion Detector

/// Detects motion using the device camera for wake-on-motion functionality
@MainActor
public final class KioskCameraMotionDetector: NSObject, ObservableObject {
    // MARK: - Published State

    /// Whether motion detection is currently active
    @Published public private(set) var isActive: Bool = false

    /// Whether motion was detected recently
    @Published public private(set) var motionDetected: Bool = false

    /// Current motion level (0.0 - 1.0)
    @Published public private(set) var motionLevel: Float = 0

    /// Camera authorization status
    @Published public private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined

    /// Internal error state for debugging; not displayed in UI
    public private(set) var errorMessage: String?

    // MARK: - Private

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.home-assistant.kiosk.motion", qos: .userInitiated)

    // Accessed only from processingQueue
    private nonisolated(unsafe) var previousFrame: CIImage?
    private var motionThreshold: Float = 0.02
    private var cooldownTimer: Timer?
    private var isInCooldown: Bool = false
    // Accessed only from processingQueue
    private nonisolated(unsafe) let ciContext = CIContext(options: [.workingColorSpace: kCFNull as Any])

    // MARK: - Initialization

    override init() {
        super.init()
        checkAuthorizationStatus()
    }

    deinit {
        captureSession?.stopRunning()
        captureSession = nil
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }

    // MARK: - Public Methods

    /// Start motion detection
    public func start() {
        guard !isActive else { return }

        checkAuthorizationStatus()

        guard authorizationStatus == .authorized else {
            Current.Log.warning("Camera not authorized for motion detection (status: \(authorizationStatus.rawValue))")
            return
        }

        Current.Log.info("Starting camera motion detection")

        updateSensitivity()
        setupCaptureSession()

        processingQueue.async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isActive = true
                self?.errorMessage = nil
            }
        }
    }

    /// Stop motion detection
    public func stop() {
        guard isActive else { return }

        Current.Log.info("Stopping camera motion detection")

        processingQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.previousFrame = nil
            DispatchQueue.main.async {
                self?.isActive = false
                self?.motionDetected = false
                self?.motionLevel = 0
            }
        }

        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }

    /// Request camera authorization
    public func requestAuthorization() async -> Bool {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return status
    }

    /// Update sensitivity from current settings
    public func updateSensitivity(_ sensitivity: MotionSensitivity) {
        motionThreshold = sensitivity.threshold
        Current.Log.info("Motion sensitivity set to \(sensitivity.rawValue), threshold: \(motionThreshold)")
    }

    // MARK: - Private Methods

    private func updateSensitivity() {
        let sensitivity = KioskModeManager.shared.settings.cameraMotionSensitivity
        motionThreshold = sensitivity.threshold
    }

    private func checkAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            errorMessage = "Front camera not available"
            Current.Log.error("Front camera not available for motion detection")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            // Configure low frame rate to save power (5 fps)
            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 5)
            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 5)
            camera.unlockForConfiguration()
        } catch {
            errorMessage = "Failed to configure camera: \(error.localizedDescription)"
            Current.Log.error("Camera configuration error: \(error)")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        captureSession = session
        videoOutput = output
    }

    /// Process a video frame for motion detection. Called on processingQueue.
    private nonisolated func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let previous = previousFrame else {
            previousFrame = ciImage
            return
        }

        let difference = calculateDifference(current: ciImage, previous: previous)
        previousFrame = ciImage

        Task { @MainActor [weak self] in
            guard let self else { return }
            motionLevel = difference
            if difference > motionThreshold, !isInCooldown {
                handleMotionDetected()
            }
        }
    }

    private nonisolated func calculateDifference(current: CIImage, previous: CIImage) -> Float {
        let differenceFilter = CIFilter(name: "CIDifferenceBlendMode")
        differenceFilter?.setValue(current, forKey: kCIInputImageKey)
        differenceFilter?.setValue(previous, forKey: kCIInputBackgroundImageKey)

        guard let differenceImage = differenceFilter?.outputImage else { return 0 }

        let extentVector = CIVector(
            x: differenceImage.extent.origin.x,
            y: differenceImage.extent.origin.y,
            z: differenceImage.extent.size.width,
            w: differenceImage.extent.size.height
        )

        let averageFilter = CIFilter(name: "CIAreaAverage")
        averageFilter?.setValue(differenceImage, forKey: kCIInputImageKey)
        averageFilter?.setValue(extentVector, forKey: kCIInputExtentKey)

        guard let outputImage = averageFilter?.outputImage else { return 0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0

        return (r + g + b) / 3.0
    }

    private func handleMotionDetected() {
        motionDetected = true
        isInCooldown = true

        Current.Log.info("Motion detected (level: \(motionLevel))")

        // 2-second cooldown to prevent rapid re-triggering
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isInCooldown = false
                self?.motionDetected = false
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension KioskCameraMotionDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processFrame(pixelBuffer)
    }
}
