import AVFoundation
import Combine
import Shared
import UIKit
import Vision

// MARK: - Kiosk Presence Detector

/// Detects human presence and faces using Apple's Vision framework
@MainActor
public final class KioskPresenceDetector: NSObject, ObservableObject {
    // MARK: - Published State

    /// Whether presence detection is currently active
    @Published public private(set) var isActive: Bool = false

    /// Whether a person is currently detected
    @Published public private(set) var personDetected: Bool = false

    /// Whether a face is currently detected
    @Published public private(set) var faceDetected: Bool = false

    /// Number of faces detected
    @Published public private(set) var faceCount: Int = 0

    /// Last detection timestamp
    @Published public private(set) var lastDetectionTime: Date?

    /// Camera authorization status
    @Published public private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined

    /// Internal error state for debugging; not displayed in UI
    public private(set) var errorMessage: String?

    // MARK: - Private

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.home-assistant.kiosk.presence", qos: .userInitiated)

    // Vision requests — set once in init, read from processingQueue
    private nonisolated(unsafe) var personDetectionRequest: VNDetectHumanRectanglesRequest?
    private nonisolated(unsafe) var faceDetectionRequest: VNDetectFaceRectanglesRequest?

    // State tracking with hysteresis
    private var consecutiveDetections: Int = 0
    private var consecutiveMisses: Int = 0
    private let detectionThreshold: Int = 2 // Frames needed to confirm detection
    private let missThreshold: Int = 5 // Frames needed to start absence countdown

    private var presenceTimeout: Timer?
    private let presenceTimeoutInterval: TimeInterval = 10 // Seconds before marking as absent

    // MARK: - Initialization

    override init() {
        super.init()
        checkAuthorizationStatus()
        setupVisionRequests()
    }

    deinit {
        captureSession?.stopRunning()
        captureSession = nil
        presenceTimeout?.invalidate()
        presenceTimeout = nil
    }

    // MARK: - Public Methods

    /// Start presence detection
    public func start(faceDetectionEnabled: Bool) {
        guard !isActive else { return }

        checkAuthorizationStatus()

        guard authorizationStatus == .authorized else {
            Current.Log.warning(
                "Camera not authorized for presence detection (status: \(authorizationStatus.rawValue))"
            )
            return
        }

        Current.Log.info("Starting presence detection (face detection: \(faceDetectionEnabled))")

        setupCaptureSession(faceDetectionEnabled: faceDetectionEnabled)

        processingQueue.async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isActive = true
                self?.errorMessage = nil
            }
        }
    }

    /// Stop presence detection
    public func stop() {
        guard isActive else { return }

        Current.Log.info("Stopping presence detection")

        processingQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.isActive = false
                self?.personDetected = false
                self?.faceDetected = false
                self?.faceCount = 0
            }
        }

        presenceTimeout?.invalidate()
        presenceTimeout = nil
    }

    /// Request camera authorization
    public func requestAuthorization() async -> Bool {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return status
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func setupVisionRequests() {
        personDetectionRequest = VNDetectHumanRectanglesRequest { [weak self] request, error in
            if let error {
                Current.Log.error("Person detection error: \(error)")
                return
            }
            self?.handlePersonDetectionResults(request.results as? [VNHumanObservation])
        }
        personDetectionRequest?.upperBodyOnly = true

        faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let error {
                Current.Log.error("Face detection error: \(error)")
                return
            }
            self?.handleFaceDetectionResults(request.results as? [VNFaceObservation])
        }
    }

    private func setupCaptureSession(faceDetectionEnabled: Bool) {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            errorMessage = "Front camera not available"
            Current.Log.error("Front camera not available for presence detection")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            // Configure frame rate: 10 fps for face detection, 3 fps for person only
            try camera.lockForConfiguration()
            let timescale: CMTimeScale = faceDetectionEnabled ? 10 : 3
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: timescale)
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

    /// Process a video frame for presence detection. Called on processingQueue.
    private nonisolated func processFrame(
        _ pixelBuffer: CVPixelBuffer,
        presenceEnabled: Bool,
        faceDetectionEnabled: Bool
    ) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            var requests: [VNRequest] = []

            if presenceEnabled, let personRequest = personDetectionRequest {
                requests.append(personRequest)
            }

            if faceDetectionEnabled, let faceRequest = faceDetectionRequest {
                requests.append(faceRequest)
            }

            if !requests.isEmpty {
                try handler.perform(requests)
            }
        } catch {
            Current.Log.error("Vision request error: \(error)")
        }
    }

    private func handlePersonDetectionResults(_ results: [VNHumanObservation]?) {
        let detected = !(results?.isEmpty ?? true)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            updatePresenceState(detected: detected)
        }
    }

    private func handleFaceDetectionResults(_ results: [VNFaceObservation]?) {
        let faces = results ?? []
        let detected = !faces.isEmpty

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let previouslyDetected = faceDetected
            let previousCount = faceCount

            faceCount = faces.count
            faceDetected = detected

            if detected != previouslyDetected || faces.count != previousCount {
                if detected {
                    lastDetectionTime = Current.date()
                    Current.Log.info("Face detected (count: \(faces.count))")
                }
            }
        }
    }

    private func updatePresenceState(detected: Bool) {
        if detected {
            consecutiveDetections += 1
            consecutiveMisses = 0

            // Reset timeout
            presenceTimeout?.invalidate()
            presenceTimeout = Timer.scheduledTimer(
                withTimeInterval: presenceTimeoutInterval,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handlePresenceTimeout()
                }
            }

            if consecutiveDetections >= detectionThreshold, !personDetected {
                personDetected = true
                lastDetectionTime = Current.date()
                Current.Log.info("Person presence detected")
            }
        } else {
            consecutiveMisses += 1
            consecutiveDetections = 0

            // Don't immediately mark as absent; wait for timeout
            // This prevents flickering when person moves slightly
        }
    }

    private func handlePresenceTimeout() {
        if personDetected {
            personDetected = false
            faceDetected = false
            faceCount = 0
            Current.Log.info("Person presence timeout - marking as absent")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension KioskPresenceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Read settings on MainActor, then process on processingQueue
        Task { @MainActor [weak self] in
            guard let self else { return }
            let settings = KioskModeManager.shared.settings
            let presenceEnabled = settings.cameraPresenceEnabled
            let faceEnabled = settings.cameraFaceDetectionEnabled
            processingQueue.async { [weak self] in
                self?.processFrame(
                    pixelBuffer,
                    presenceEnabled: presenceEnabled,
                    faceDetectionEnabled: faceEnabled
                )
            }
        }
    }
}
