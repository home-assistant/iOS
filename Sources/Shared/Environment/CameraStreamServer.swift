import Foundation

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreImage
import CoreVideo
import Network

/// Serves the front camera frames captured by `MotionDetectionManager` as an MJPEG
/// HTTP stream (`multipart/x-mixed-replace`), consumable by Home Assistant's MJPEG
/// camera integration at `http://<device-ip>:<port>/`.
///
/// Activation is driven by the "Camera Stream" sensor's enabled state: while active,
/// the listener runs and the camera capture session is kept alive continuously (not
/// only while clients are connected), so the stream is instantly available. Like all
/// camera capture, this only works while the app is in the foreground.
public final class CameraStreamServer: NSObject {
    private enum UserDefaultsKeys: String {
        case port = "camera_stream_port"
    }

    private static let boundary = "hacameraframe"

    private let queue = DispatchQueue(label: "camera-stream-server")
    private let encodingQueue = DispatchQueue(label: "camera-stream-encoding")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var active = false
    private var isObservingCamera = false
    private lazy var ciContext = CIContext()

    /// Called (on the main queue) whenever the streaming state changes, so the
    /// Camera Stream sensor can push an update.
    public var onStateChange: (() -> Void)?

    // MARK: - State

    public var isActive: Bool {
        queue.sync { active }
    }

    public var isStreaming: Bool {
        queue.sync { !connections.isEmpty }
    }

    public var clientCount: Int {
        queue.sync { connections.count }
    }

    /// The URL clients should use to consume the stream, based on the Wi-Fi
    /// interface address. `nil` when the device has no Wi-Fi IPv4 address.
    public var streamURL: String? {
        guard let address = Self.localIPAddress() else { return nil }
        return "http://\(address):\(Int(port))/"
    }

    /// IPv4 address of the Wi-Fi interface (`en0`), if any.
    private static func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let ifaAddr = interface.ifa_addr,
                  ifaAddr.pointee.sa_family == UInt8(AF_INET),
                  String(cString: interface.ifa_name) == "en0" else {
                continue
            }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                ifaAddr,
                socklen_t(ifaAddr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                address = String(cString: hostname)
            }
        }
        return address
    }

    // MARK: - Persisted settings

    public var port: Double {
        get {
            let prefs = Current.settingsStore.prefs
            if prefs.object(forKey: UserDefaultsKeys.port.rawValue) == nil {
                return 8090
            }
            return prefs.double(forKey: UserDefaultsKeys.port.rawValue)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.port.rawValue)
            queue.async { [weak self] in
                guard let self, self.active else { return }
                // Restart on the new port.
                self.stopListener()
                self.startListener()
                self.notifyStateChange()
            }
        }
    }

    // MARK: - Activation

    /// Turns the stream server on or off. While on, the listener accepts clients and
    /// the camera runs continuously (foreground only).
    public func setActive(_ newValue: Bool) {
        queue.async { [weak self] in
            guard let self, self.active != newValue else { return }
            self.active = newValue
            if newValue {
                self.startListener()
            } else {
                self.stopListener()
            }
            self.updateCameraObservation()
            self.notifyStateChange()
        }
    }

    private func startListener() {
        guard listener == nil else { return }
        let portValue = UInt16(min(max(port, 1024), 65535))
        guard let nwPort = NWEndpoint.Port(rawValue: portValue) else { return }

        do {
            let listener = try NWListener(using: .tcp, on: nwPort)
            listener.newConnectionHandler = { [weak self] connection in
                self?.queue.async {
                    self?.setup(connection: connection)
                }
            }
            listener.stateUpdateHandler = { state in
                if case let .failed(error) = state {
                    Current.Log.error("Camera stream: listener failed: \(error)")
                }
            }
            listener.start(queue: queue)
            self.listener = listener
            Current.Log.info("Camera stream: listening on port \(portValue)")
        } catch {
            Current.Log.error("Camera stream: failed to start listener: \(error)")
        }
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
    }

    // MARK: - Connections

    private func setup(connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.queue.async {
                    self?.remove(connection: connection)
                }
            default:
                break
            }
        }
        connection.start(queue: queue)

        // Read (and discard) the HTTP request, then reply with the multipart header
        // and keep the connection open for frames.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] _, _, _, error in
            guard let self, error == nil else {
                connection.cancel()
                return
            }
            let header = [
                "HTTP/1.1 200 OK",
                "Content-Type: multipart/x-mixed-replace; boundary=\(Self.boundary)",
                "Cache-Control: no-cache",
                "",
                "",
            ].joined(separator: "\r\n")

            connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                self.queue.async {
                    if error == nil {
                        self.connections[ObjectIdentifier(connection)] = connection
                        Current.Log.info("Camera stream: client connected (\(self.connections.count) total)")
                        self.notifyStateChange()
                    } else {
                        connection.cancel()
                    }
                }
            })
        }
    }

    private func remove(connection: NWConnection) {
        guard connections.removeValue(forKey: ObjectIdentifier(connection)) != nil else { return }
        Current.Log.info("Camera stream: client disconnected (\(connections.count) left)")
        notifyStateChange()
    }

    private func notifyStateChange() {
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?()
        }
    }

    /// While active, hold a camera observation so the shared capture session runs
    /// continuously and the stream is instantly available to clients.
    private func updateCameraObservation() {
        let shouldObserve = active
        guard shouldObserve != isObservingCamera else { return }
        isObservingCamera = shouldObserve
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if shouldObserve {
                Current.motionDetection.register(observer: self)
            } else {
                Current.motionDetection.unregister(observer: self)
            }
        }
    }

    // MARK: - Frames

    /// Called by `MotionDetectionManager` with every captured frame (on its
    /// processing queue). Encodes to JPEG once and broadcasts to all clients.
    ///
    /// The closure capture retains the `CVPixelBuffer` (CoreVideo objects are
    /// ARC-managed in Swift), so the buffer stays valid for async encoding; the
    /// output's `alwaysDiscardsLateVideoFrames` prevents pool starvation.
    public func handle(frame: CVPixelBuffer) {
        encodingQueue.async { [weak self] in
            guard let self, !self.queue.sync(execute: { self.connections.isEmpty }) else { return }

            let image = CIImage(cvPixelBuffer: frame)
            guard let jpeg = self.ciContext.jpegRepresentation(
                of: image,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            ) else { return }

            let part = [
                "--\(Self.boundary)",
                "Content-Type: image/jpeg",
                "Content-Length: \(jpeg.count)",
                "",
                "",
            ].joined(separator: "\r\n")

            var payload = Data(part.utf8)
            payload.append(jpeg)
            payload.append(Data("\r\n".utf8))

            self.queue.async {
                for connection in self.connections.values {
                    connection.send(content: payload, completion: .idempotent)
                }
            }
        }
    }
}

// MARK: - MotionDetectionObserver

extension CameraStreamServer: MotionDetectionObserver {
    // Registration is only used to keep the capture session running while the
    // stream server is active; motion state changes are irrelevant to the stream.
    public func motionStateDidChange(for manager: MotionDetectionManager) {}
}

#else

/// Stub for platforms without camera capture (watchOS, Mac Catalyst).
public final class CameraStreamServer: NSObject {
    public var onStateChange: (() -> Void)?
    public var isActive: Bool { false }
    public var isStreaming: Bool { false }
    public var clientCount: Int { 0 }
    public var port: Double = 8090
    public func setActive(_ newValue: Bool) {}
}

#endif
