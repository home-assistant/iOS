import AVFoundation
import Combine
import Shared
import UIKit
import Vision

// MARK: - Presence Detector

/// Detects human presence and faces using Apple's Vision framework
@MainActor
public final class PresenceDetector: NSObject, ObservableObject {
    // MARK: - Singleton

    public static let shared = PresenceDetector()

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

    /// Error message if detection failed
    @Published public private(set) var errorMessage: String?

    // MARK: - Callbacks

    /// Called when presence state changes
    public var onPresenceChanged: ((Bool) -> Void)?

    /// Called when face detection state changes
    public var onFaceDetectionChanged: ((Bool, Int) -> Void)?

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.haframe.presence", qos: .userInitiated)

    // Vision requests
    private var personDetectionRequest: VNDetectHumanRectanglesRequest?
    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?

    // State tracking
    private var consecutiveDetections: Int = 0
    private var consecutiveMisses: Int = 0
    private let detectionThreshold: Int = 2 // Frames needed to confirm detection
    private let missThreshold: Int = 5 // Frames needed to confirm absence

    private var presenceTimeout: Timer?
    private let presenceTimeoutInterval: TimeInterval = 10 // Seconds before marking as absent

    // MARK: - Initialization

    private override init() {
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
    public func start() {
        guard !isActive else { return }

        // Re-check authorization status before starting
        checkAuthorizationStatus()

        guard authorizationStatus == .authorized else {
            Current.Log.warning("Camera not authorized for presence detection (status: \(authorizationStatus.rawValue))")
            return
        }

        Current.Log.info("Starting presence detection")

        setupCaptureSession()

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
        // Person detection request
        personDetectionRequest = VNDetectHumanRectanglesRequest { [weak self] request, error in
            if let error {
                Current.Log.error("Person detection error: \(error)")
                return
            }
            self?.handlePersonDetectionResults(request.results as? [VNHumanObservation])
        }
        personDetectionRequest?.upperBodyOnly = true // More efficient, good for wall-mounted

        // Face detection request
        faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let error {
                Current.Log.error("Face detection error: \(error)")
                return
            }
            self?.handleFaceDetectionResults(request.results as? [VNFaceObservation])
        }
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium // Balance quality and performance

        // Get front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            errorMessage = "Front camera not available"
            Current.Log.error("Front camera not available for presence detection")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            // Configure frame rate based on whether we need face detection
            try camera.lockForConfiguration()
            if settings.cameraFaceDetectionEnabled {
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 10) // 10 fps for face
            } else {
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 3) // 3 fps for person only
            }
            camera.unlockForConfiguration()
        } catch {
            errorMessage = "Failed to configure camera: \(error.localizedDescription)"
            Current.Log.error("Camera configuration error: \(error)")
            return
        }

        // Setup video output
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

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            var requests: [VNRequest] = []

            // Always run person detection if enabled
            if settings.cameraPresenceEnabled, let personRequest = personDetectionRequest {
                requests.append(personRequest)
            }

            // Run face detection if enabled
            if settings.cameraFaceDetectionEnabled, let faceRequest = faceDetectionRequest {
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
            self.updatePresenceState(detected: detected)
        }
    }

    private func handleFaceDetectionResults(_ results: [VNFaceObservation]?) {
        let faces = results ?? []
        let detected = !faces.isEmpty

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let previouslyDetected = self.faceDetected
            let previousCount = self.faceCount

            self.faceCount = faces.count
            self.faceDetected = detected

            if detected != previouslyDetected || faces.count != previousCount {
                self.onFaceDetectionChanged?(detected, faces.count)

                if detected {
                    self.lastDetectionTime = Date()
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

            if consecutiveDetections >= detectionThreshold && !personDetected {
                personDetected = true
                lastDetectionTime = Date()
                onPresenceChanged?(true)
                Current.Log.info("Person presence detected")
            }
        } else {
            consecutiveMisses += 1
            consecutiveDetections = 0

            if consecutiveMisses >= missThreshold && personDetected {
                // Don't immediately mark as absent - wait for timeout
                // This prevents flickering when person moves slightly
            }
        }
    }

    private func handlePresenceTimeout() {
        if personDetected {
            personDetected = false
            faceDetected = false
            faceCount = 0
            onPresenceChanged?(false)
            Current.Log.info("Person presence timeout - marking as absent")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension PresenceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        Task { @MainActor in
            processFrame(pixelBuffer)
        }
    }
}

// MARK: - Privacy Helpers

extension PresenceDetector {
    /// Check if detection is allowed based on privacy settings
    public var isDetectionAllowed: Bool {
        settings.cameraPresenceEnabled || settings.cameraFaceDetectionEnabled
    }

    /// Get privacy-safe description of current state
    public var privacySafeStatus: String {
        if !isActive {
            return "Inactive"
        } else if personDetected {
            return faceDetected ? "Face detected" : "Person detected"
        } else {
            return "Monitoring"
        }
    }
}
