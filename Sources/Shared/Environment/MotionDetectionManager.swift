import Foundation

public protocol MotionDetectionObserver: AnyObject {
    func motionStateDidChange(for manager: MotionDetectionManager)
}

#if os(iOS) && !targetEnvironment(macCatalyst)
import AVFoundation
import UIKit

/// Detects motion using the device's front camera via simple frame differencing
/// on the luminance (Y) plane. Designed for kiosk/wall-mounted usage: the capture
/// session only runs while at least one observer is registered and the app is in
/// the foreground.
public final class MotionDetectionManager: NSObject {
    // MARK: - Public state

    public private(set) var isMotionDetected = false
    public private(set) var lastMotionDate: Date?
    /// Ratio (0...1) of sampled pixels that changed in the last processed frame.
    public private(set) var lastChangedRatio: Double = 0

    public var canDetectMotion: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    public var attributes: [String: Any] {
        [
            "Frame Rate": frameRate,
            "Area Threshold (%)": areaThresholdPercent,
            "Clear Delay (s)": clearDelay,
            "Last Changed Ratio (%)": (lastChangedRatio * 100).rounded(),
            "Last Motion": lastMotionDate?.description ?? "never",
        ]
    }

    // MARK: - Persisted settings

    private enum UserDefaultsKeys: String {
        case frameRate = "motion_detection_frame_rate"
        case areaThreshold = "motion_detection_area_threshold"
        case clearDelay = "motion_detection_clear_delay"
    }

    /// Camera frame rate in frames per second. Lower values reduce power draw and
    /// heat significantly; frame differencing works well down to 1-2 fps.
    public var frameRate: Double {
        get {
            let prefs = Current.settingsStore.prefs
            if prefs.object(forKey: UserDefaultsKeys.frameRate.rawValue) == nil {
                return 10.0
            }
            return prefs.double(forKey: UserDefaultsKeys.frameRate.rawValue)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.frameRate.rawValue)
            sessionQueue.async { [weak self] in
                self?.applyFrameRate()
            }
        }
    }

    /// Percentage (0-100) of sampled pixels that must change for a frame to count
    /// as motion. Lower = more sensitive.
    public var areaThresholdPercent: Double {
        get {
            let prefs = Current.settingsStore.prefs
            if prefs.object(forKey: UserDefaultsKeys.areaThreshold.rawValue) == nil {
                return 2.0
            }
            return prefs.double(forKey: UserDefaultsKeys.areaThreshold.rawValue)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.areaThreshold.rawValue)
        }
    }

    /// Seconds without motion before the state flips back to off (hysteresis, avoids
    /// the binary sensor flapping).
    public var clearDelay: Double {
        get {
            let prefs = Current.settingsStore.prefs
            if prefs.object(forKey: UserDefaultsKeys.clearDelay.rawValue) == nil {
                return 30.0
            }
            return prefs.double(forKey: UserDefaultsKeys.clearDelay.rawValue)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.clearDelay.rawValue)
        }
    }

    /// Per-pixel luminance delta (0-255) above which a pixel counts as changed.
    /// Kept internal: the area threshold is the user-facing sensitivity knob.
    private let pixelThreshold: Int = 25

    // MARK: - Capture plumbing

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "motion-detection-session")
    private let processingQueue = DispatchQueue(label: "motion-detection-frames")
    private var isCaptureSessionConfigured = false
    private var captureDevice: AVCaptureDevice?

    /// Subsampling step over the Y plane; with VGA input this yields roughly
    /// 80x60 samples per frame, plenty for presence detection.
    private let sampleStep = 8
    private var previousSamples: [UInt8]?

    private var clearTimer: Timer?
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)
    private var wantsRunning = false

    override public init() {
        super.init()
        captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - Observers

    /// The capture session runs only while at least one observer is registered.
    public func register(observer: MotionDetectionObserver) {
        let wasEmpty = observers.allObjects.isEmpty
        observers.add(observer)
        if wasEmpty {
            wantsRunning = true
            startSession()
        }
    }

    public func unregister(observer: MotionDetectionObserver) {
        observers.remove(observer)
        if observers.allObjects.isEmpty {
            wantsRunning = false
            stopSession()
        }
    }

    private func notifyObservers() {
        let observers = observers.allObjects.compactMap { $0 as? MotionDetectionObserver }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for observer in observers {
                observer.motionStateDidChange(for: self)
            }
        }
    }

    // MARK: - Session lifecycle

    private func startSession() {
        guard canDetectMotion else { return }

        checkAuthorization { [weak self] authorized in
            guard let self, authorized else {
                Current.Log.error("Motion detection: camera access not authorized")
                return
            }
            self.sessionQueue.async {
                guard self.wantsRunning else { return }
                if !self.isCaptureSessionConfigured {
                    self.configureCaptureSession()
                }
                if self.isCaptureSessionConfigured, !self.captureSession.isRunning {
                    self.previousSamples = nil
                    self.captureSession.startRunning()
                    Current.Log.info("Motion detection: capture session started")
                }
            }
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            self.previousSamples = nil
            Current.Log.info("Motion detection: capture session stopped")
        }
        DispatchQueue.main.async { [weak self] in
            self?.clearTimer?.invalidate()
            self?.clearTimer = nil
            self?.setMotionDetected(false)
        }
    }

    @objc private func applicationDidEnterBackground() {
        // iOS forbids camera capture in the background; stop cleanly.
        stopSession()
    }

    @objc private func applicationDidBecomeActive() {
        if wantsRunning {
            startSession()
        }
    }

    private func checkAuthorization(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func configureCaptureSession() {
        guard let captureDevice,
              let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            Current.Log.error("Motion detection: failed to obtain video input")
            return
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Low resolution is more than enough for frame differencing and keeps
        // power draw down.
        if captureSession.canSetSessionPreset(.vga640x480) {
            captureSession.sessionPreset = .vga640x480
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)

        guard captureSession.canAddInput(deviceInput),
              captureSession.canAddOutput(videoOutput) else {
            Current.Log.error("Motion detection: unable to add capture input/output")
            return
        }

        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)

        isCaptureSessionConfigured = true
        applyFrameRate()
    }

    /// Clamps and applies the configured frame rate to the capture device.
    private func applyFrameRate() {
        guard let captureDevice, isCaptureSessionConfigured else { return }

        let fps = min(max(frameRate, 1), 30)
        let duration = CMTime(value: 1, timescale: CMTimeScale(fps))

        do {
            try captureDevice.lockForConfiguration()
            defer { captureDevice.unlockForConfiguration() }
            captureDevice.activeVideoMinFrameDuration = duration
            captureDevice.activeVideoMaxFrameDuration = duration
        } catch {
            Current.Log.error("Motion detection: failed to set frame rate: \(error)")
        }
    }

    // MARK: - Motion state

    private func handleMotionFrame() {
        lastMotionDate = Current.date()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.clearTimer?.invalidate()
            self.clearTimer = Timer.scheduledTimer(
                withTimeInterval: self.clearDelay,
                repeats: false
            ) { [weak self] _ in
                self?.setMotionDetected(false)
            }
            self.setMotionDetected(true)
        }
    }

    private func setMotionDetected(_ detected: Bool) {
        guard detected != isMotionDetected else { return }
        isMotionDetected = detected
        notifyObservers()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MotionDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Feed the MJPEG stream server (no-op when no client is connected).
        Current.cameraStreamServer.handle(frame: pixelBuffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        // Plane 0 of 420YpCbCr8BiPlanar is the luminance (Y) plane: one byte per
        // pixel, so we can diff without any color conversion.
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Subsample the Y plane into a compact buffer.
        var samples = [UInt8]()
        samples.reserveCapacity((width / sampleStep + 1) * (height / sampleStep + 1))
        var row = 0
        while row < height {
            var column = 0
            let rowStart = row * bytesPerRow
            while column < width {
                samples.append(pointer[rowStart + column])
                column += sampleStep
            }
            row += sampleStep
        }

        defer { previousSamples = samples }

        guard let previous = previousSamples, previous.count == samples.count, !samples.isEmpty else {
            return
        }

        var changedCount = 0
        for index in samples.indices where abs(Int(samples[index]) - Int(previous[index])) > pixelThreshold {
            changedCount += 1
        }

        let changedRatio = Double(changedCount) / Double(samples.count)
        lastChangedRatio = changedRatio

        if changedRatio * 100 >= areaThresholdPercent {
            handleMotionFrame()
        }
    }
}

#else

/// Stub for platforms without front-camera capture (watchOS, Mac Catalyst) so the
/// Shared target compiles everywhere; `MotionSensor` reports unavailable there.
public final class MotionDetectionManager {
    public private(set) var isMotionDetected = false
    public var canDetectMotion: Bool { false }
    public var attributes: [String: Any] { [:] }

    public init() {}

    public func register(observer: MotionDetectionObserver) {}
    public func unregister(observer: MotionDetectionObserver) {}
}

#endif
