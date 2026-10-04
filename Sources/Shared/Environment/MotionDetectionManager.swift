import Foundation

public protocol MotionDetectionObserver: AnyObject {
    func motionStateDidChange(for manager: MotionDetectionManager)
}

#if os(iOS) && !targetEnvironment(macCatalyst)
import AVFoundation
import HAKit
import UIKit

/// Detects motion using the device's front camera via simple frame differencing
/// on the luminance (Y) plane. Designed for kiosk/wall-mounted usage: the capture
/// session only runs while at least one observer is registered and the app is in
/// the foreground.
public class MotionDetectionManager: NSObject {
    // MARK: - Public state

    /// Detection state is written on the capture/processing queue and read from
    /// arbitrary contexts (sensor providers, observers), so it lives behind a lock.
    private struct DetectionState {
        var isMotionDetected = false
        var lastMotionDate: Date?
        var lastChangedRatio: Double = 0
    }

    private let detectionState = HAProtected<DetectionState>(value: .init())

    public var isMotionDetected: Bool {
        detectionState.read { $0.isMotionDetected }
    }

    public var lastMotionDate: Date? {
        detectionState.read { $0.lastMotionDate }
    }

    /// Ratio (0...1) of sampled pixels that changed in the last processed frame.
    public var lastChangedRatio: Double {
        detectionState.read { $0.lastChangedRatio }
    }

    public var canDetectMotion: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    public var attributes: [String: Any] {
        [
            "Frame Rate": frameRate,
            "Area Threshold (%)": areaThresholdPercent,
            "Clear Delay (s)": clearDelay,
            "Last Changed Ratio (%)": (lastChangedRatio * 100).rounded(),
            "Last Motion": lastMotionDate.map {
                DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .medium)
            } ?? "never",
        ]
    }

    // MARK: - Persisted settings

    private enum UserDefaultsKeys: String {
        case frameRate = "motion_detection_frame_rate"
        case areaThreshold = "motion_detection_area_threshold"
        case clearDelay = "motion_detection_clear_delay"
    }

    /// Motion detection frame rate in frames per second. Lower values reduce power
    /// draw and heat significantly; frame differencing works well down to 1-2 fps.
    /// The capture session itself runs at the highest rate any active consumer needs
    /// (see `applyFrameRate`); detection then samples frames at this rate.
    public var frameRate: Double {
        get {
            storedSetting(for: .frameRate, default: 8.0)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.frameRate.rawValue)
            refreshFrameRate()
        }
    }

    /// Re-evaluates the capture frame rate from all active consumers. Called when any
    /// consumer's rate or activation changes (e.g. the stream server turning on).
    public func refreshFrameRate() {
        sessionQueue.async { [weak self] in
            self?.applyFrameRate()
        }
    }

    /// Percentage (0-100) of sampled pixels that must change for a frame to count
    /// as motion. Lower = more sensitive.
    public var areaThresholdPercent: Double {
        get {
            storedSetting(for: .areaThreshold, default: 40.0)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.areaThreshold.rawValue)
        }
    }

    /// Seconds without motion before the state flips back to off (hysteresis, avoids
    /// the binary sensor flapping).
    public var clearDelay: Double {
        get {
            storedSetting(for: .clearDelay, default: 15.0)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.clearDelay.rawValue)
        }
    }

    private func storedSetting(for key: UserDefaultsKeys, default defaultValue: Double) -> Double {
        let prefs = Current.settingsStore.prefs
        guard prefs.object(forKey: key.rawValue) != nil else { return defaultValue }
        return prefs.double(forKey: key.rawValue)
    }

    /// Per-pixel luminance delta (0-255) above which a pixel counts as changed.
    /// Kept internal: the area threshold is the user-facing sensitivity knob.
    private static let pixelThreshold = 25

    // MARK: - Capture plumbing

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "motion-detection-session")
    private let processingQueue = DispatchQueue(label: "motion-detection-frames")
    private var isCaptureSessionConfigured = false
    private var captureDevice: AVCaptureDevice?
    /// Retained so the capture connection can be re-oriented as the device rotates.
    private var videoOutput: AVCaptureVideoDataOutput?

    /// Subsampling step over the Y plane; with VGA input this yields roughly
    /// 80x60 samples per frame, plenty for presence detection.
    private let sampleStep = 8
    private var previousSamples: [UInt8]?
    /// Timestamp of the last frame the detection pipeline processed; only touched on
    /// the processing queue. Lets detection run at `frameRate` even when the capture
    /// session runs faster for streaming.
    private var lastDetectionTime: CFAbsoluteTime = 0

    private var clearTimer: Timer?
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)
    private var wantsRunning = false

    // MARK: - Capture health

    /// How often the stall watchdog checks that frames are still arriving.
    private static let stallCheckInterval: TimeInterval = 5

    /// System uptime of the last frame the camera delivered. Written on the processing
    /// queue, read by the stall watchdog on the session queue.
    private let lastFrameUptime = HAProtected<TimeInterval>(value: 0)
    /// System uptime of the last time capture was started or rebuilt. Session queue only.
    private var lastCaptureStartUptime: TimeInterval = 0
    /// Rebuilds since frames last arrived; drives the watchdog's back-off. Session queue only.
    private var recoveryAttempts = 0
    /// Runs on the session queue while capture should be running.
    private var stallWatchdog: DispatchSourceTimer?

    override public init() {
        super.init()
        self.captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionRuntimeError(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionWasInterrupted(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureSessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
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
            setGeneratingOrientationNotifications(true)
            startSession()
        }
    }

    public func unregister(observer: MotionDetectionObserver) {
        observers.remove(observer)
        if observers.allObjects.isEmpty {
            wantsRunning = false
            setGeneratingOrientationNotifications(false)
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
            sessionQueue.async {
                guard self.wantsRunning else { return }
                if !self.isCaptureSessionConfigured {
                    self.configureCaptureSession()
                }
                if self.isCaptureSessionConfigured, !self.captureSession.isRunning {
                    self.previousSamples = nil
                    self.lastCaptureStartUptime = ProcessInfo.processInfo.systemUptime
                    self.captureSession.startRunning()
                    Current.Log.info("Motion detection: capture session started")
                }
                self.startStallWatchdog()
            }
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            stopStallWatchdog()
            guard captureSession.isRunning else { return }
            captureSession.stopRunning()
            previousSamples = nil
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
            // Orientation notifications are suspended in the background, so the device
            // may have been rotated since the session last ran.
            refreshVideoOrientation()
        }
    }

    // MARK: - Recovery

    @objc private func captureSessionRuntimeError(_ notification: Notification) {
        // The session has stopped. The stall watchdog rebuilds it once frames have been
        // missing for a while, which also gives a camera service that was just killed
        // time to come back.
        let error = notification.userInfo?[AVCaptureSessionErrorKey] ?? "unknown"
        Current.Log.error("Motion detection: capture session runtime error: \(error)")
    }

    @objc private func captureSessionWasInterrupted(_ notification: Notification) {
        // iOS suspended capture (another app took the camera, Split View, system
        // pressure) and resumes it by itself; the watchdog leaves it alone meanwhile.
        let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] ?? "unknown"
        Current.Log.info("Motion detection: capture interrupted (reason: \(reason))")
    }

    @objc private func captureSessionInterruptionEnded() {
        Current.Log.info("Motion detection: capture interruption ended")
        sessionQueue.async { [weak self] in
            // Give the session a full stall window to resume before judging it.
            self?.lastCaptureStartUptime = ProcessInfo.processInfo.systemUptime
        }
    }

    /// How long capture may go without a frame before it's rebuilt. Doubles after each
    /// rebuild that didn't bring frames back, so a camera that stays broken isn't
    /// restarted (and logged) every few seconds.
    static func captureStallTimeout(afterRecoveryAttempts attempts: Int) -> TimeInterval {
        min(10 * pow(2, Double(min(attempts, 5))), 300)
    }

    private func startStallWatchdog() {
        guard stallWatchdog == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + Self.stallCheckInterval, repeating: Self.stallCheckInterval)
        timer.setEventHandler { [weak self] in
            self?.checkForStalledCapture()
        }
        timer.resume()
        stallWatchdog = timer
    }

    private func stopStallWatchdog() {
        stallWatchdog?.cancel()
        stallWatchdog = nil
        recoveryAttempts = 0
    }

    /// Rebuilds capture once frames have stopped arriving. Nothing else restarts it
    /// while the app stays in the foreground, as a kiosk does, so after the camera
    /// service dies or the session hits a runtime error the stream would stay dark
    /// until the app was relaunched.
    private func checkForStalledCapture() {
        guard wantsRunning, !captureSession.isInterrupted else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let lastFrame = lastFrameUptime.read { $0 }
        if lastFrame > lastCaptureStartUptime {
            recoveryAttempts = 0
        }

        let silence = now - max(lastFrame, lastCaptureStartUptime)
        guard silence >= Self.captureStallTimeout(afterRecoveryAttempts: recoveryAttempts) else { return }

        recoveryAttempts += 1
        Current.Log.error(
            "Motion detection: no frames for \(Int(silence)) s, rebuilding capture (attempt \(recoveryAttempts))"
        )
        rebuildCaptureSession()
    }

    /// Tears the capture pipeline down and builds it again around a freshly looked-up
    /// device, rather than only restarting it, so that nothing left over from a camera
    /// service that went away can keep it from delivering frames.
    private func rebuildCaptureSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }

        captureSession.beginConfiguration()
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }
        captureSession.commitConfiguration()
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        videoOutput = nil
        isCaptureSessionConfigured = false
        captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        lastCaptureStartUptime = ProcessInfo.processInfo.systemUptime
        configureCaptureSession()
        guard isCaptureSessionConfigured else { return }

        processingQueue.async { [weak self] in
            self?.previousSamples = nil
        }
        captureSession.startRunning()
        Current.Log.info("Motion detection: capture session rebuilt and started")
    }

    // MARK: - Orientation

    @objc private func deviceOrientationDidChange() {
        refreshVideoOrientation()
    }

    /// `UIDevice.orientationDidChangeNotification` is only posted while orientation
    /// notifications are being generated; the calls are reference counted, so this is
    /// balanced against observer registration.
    private func setGeneratingOrientationNotifications(_ generating: Bool) {
        DispatchQueue.main.async {
            if generating {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            } else {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            }
        }
    }

    /// Re-reads how the device is being held and applies it to the capture connection.
    /// Safe to call from any thread.
    public func refreshVideoOrientation() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let orientation = Self.currentVideoOrientation()
            sessionQueue.async { [weak self] in
                self?.apply(videoOrientation: orientation)
            }
        }
    }

    /// How the device is currently held. Prefers the physical device orientation —
    /// what matters for a camera is which way the room actually is, not whether the
    /// UI happens to be rotation-locked — and falls back to the screen's rotation
    /// when the device reports no usable orientation, which is what a flat or
    /// wall-mounted tablet reports (`.faceUp`, `.faceDown`, `.unknown`).
    ///
    /// Must be called on the main thread: it reads UIKit state.
    private static func currentVideoOrientation() -> AVCaptureVideoOrientation {
        AVCaptureVideoOrientation(deviceOrientation: UIDevice.current.orientation)
            ?? AVCaptureVideoOrientation(deviceOrientation: UIScreen.main.orientation)
            ?? .portrait
    }

    /// Rotates captured frames so they stay upright. Frames are handed to the MJPEG
    /// stream exactly as captured, so without this the stream keeps whatever fixed
    /// orientation the connection defaulted to and comes out rotated or upside down
    /// on any device that isn't held that way — routinely the case on iPad, which has
    /// no natural orientation.
    private func apply(videoOrientation: AVCaptureVideoOrientation) {
        guard let connection = videoOutput?.connection(with: .video),
              connection.isVideoOrientationSupported,
              connection.videoOrientation != videoOrientation else { return }

        connection.videoOrientation = videoOrientation
        Current.Log.info("Motion detection: capture orientation now \(videoOrientation.rawValue)")

        // Samples from before and after a rotation aren't comparable: a 180° flip
        // keeps the sample count identical, so the diff would read as a frame full of
        // motion and trip the sensor.
        processingQueue.async { [weak self] in
            self?.previousSamples = nil
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

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        guard captureSession.canAddInput(deviceInput),
              captureSession.canAddOutput(output) else {
            Current.Log.error("Motion detection: unable to add capture input/output")
            return
        }

        captureSession.addInput(deviceInput)
        captureSession.addOutput(output)
        videoOutput = output

        isCaptureSessionConfigured = true
        applyFrameRate()
        refreshVideoOrientation()
    }

    /// Applies the capture frame rate: the highest rate among active consumers
    /// (motion detection always; the MJPEG stream when its server is active),
    /// clamped to a sane range. Detection throttles itself down to `frameRate`
    /// in `captureOutput` when the capture runs faster for streaming.
    private func applyFrameRate() {
        guard let captureDevice, isCaptureSessionConfigured else { return }

        var desired = frameRate
        let streamServer = Current.cameraStreamServer
        if streamServer.isActive {
            desired = max(desired, streamServer.streamFrameRate)
        }

        let fps = min(max(desired, 1), 30)
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

    /// Ratio (0...1) of samples whose luminance changed by more than `pixelThreshold`
    /// between two equally-sized sample buffers; 0 when the buffers can't be compared.
    static func changedRatio(previous: [UInt8], current: [UInt8]) -> Double {
        guard !current.isEmpty, previous.count == current.count else { return 0 }

        var changedCount = 0
        for index in current.indices where abs(Int(current[index]) - Int(previous[index])) > pixelThreshold {
            changedCount += 1
        }
        return Double(changedCount) / Double(current.count)
    }

    private func handleMotionFrame() {
        detectionState.mutate { $0.lastMotionDate = Current.date() }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            clearTimer?.invalidate()
            clearTimer = Timer.scheduledTimer(
                withTimeInterval: clearDelay,
                repeats: false
            ) { [weak self] _ in
                self?.setMotionDetected(false)
            }
            setMotionDetected(true)
        }
    }

    private func setMotionDetected(_ detected: Bool) {
        let changed = detectionState.mutate { state -> Bool in
            guard state.isMotionDetected != detected else { return false }
            state.isMotionDetected = detected
            return true
        }
        if changed {
            notifyObservers()
        }
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
        lastFrameUptime.mutate { $0 = ProcessInfo.processInfo.systemUptime }

        // Feed the MJPEG stream server every frame (no-op when no client is connected).
        Current.cameraStreamServer.handle(frame: pixelBuffer)

        // Detection samples frames at its own rate; the capture session may run
        // faster when the stream server needs a higher frame rate. The 0.9 factor
        // tolerates capture timing jitter.
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastDetectionTime >= (1.0 / max(frameRate, 1)) * 0.9 else { return }
        lastDetectionTime = now

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
        for row in stride(from: 0, to: height, by: sampleStep) {
            let rowStart = row * bytesPerRow
            for column in stride(from: 0, to: width, by: sampleStep) {
                samples.append(pointer[rowStart + column])
            }
        }

        defer { previousSamples = samples }
        guard let previousSamples else { return }

        let changedRatio = Self.changedRatio(previous: previousSamples, current: samples)
        detectionState.mutate { $0.lastChangedRatio = changedRatio }

        if changedRatio * 100 >= areaThresholdPercent {
            handleMotionFrame()
        }
    }
}

#else

/// Stub for platforms without front-camera capture (watchOS, Mac Catalyst) so the
/// Shared target compiles everywhere; `CameraMotionSensor` reports unavailable there.
public class MotionDetectionManager {
    public private(set) var isMotionDetected = false
    public var canDetectMotion: Bool { false }
    public var attributes: [String: Any] { [:] }

    public init() {}

    public func register(observer: MotionDetectionObserver) {}
    public func unregister(observer: MotionDetectionObserver) {}
    public func refreshVideoOrientation() {}
}

#endif
