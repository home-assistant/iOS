import Foundation

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreImage
import CoreVideo
import KeychainAccess
import Network

/// Serves the front camera frames captured by `MotionDetectionManager` as an MJPEG
/// HTTP stream (`multipart/x-mixed-replace`), consumable by Home Assistant's MJPEG
/// camera integration at `http://<device-ip>:<port>/`.
///
/// Activation is driven by the "Camera Stream" sensor's enabled state: while active,
/// the listener runs and the camera capture session is kept alive continuously (not
/// only while clients are connected), so the stream is instantly available. Like all
/// camera capture, this only works while the app is in the foreground.
public class CameraStreamServer {
    private enum UserDefaultsKeys: String {
        case port = "camera_stream_port"
        case frameRate = "camera_stream_frame_rate"
        case username = "camera_stream_username"
    }

    private static let passwordKeychainKey = "camera_stream_password"
    private static let authRealm = "Home Assistant Camera"

    private static let boundary = "hacameraframe"

    /// Encoding in a plain SDR color space stops Core Image from trying (and failing,
    /// noisily) to build an HDR gain map for the JPEG when the camera delivers
    /// wide-gamut buffers.
    private static let sdrColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    private let keychain = AppConstants.Keychain
    private let queue = DispatchQueue(label: "camera-stream-server")
    private let encodingQueue = DispatchQueue(label: "camera-stream-encoding")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var active = false
    private var isObservingCamera = false
    private lazy var ciContext = CIContext(options: [.workingColorSpace: Self.sdrColorSpace])

    /// Called (on the main queue) whenever the streaming state changes, so the
    /// Camera Stream sensor can push an update.
    public var onStateChange: (() -> Void)?

    public init() {}

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
    /// The `/camera` path is canonical/advertised; the server accepts any path.
    public var streamURL: String? {
        guard let address = Self.localIPAddress() else { return nil }
        return "http://\(address):\(port)/camera"
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

    public var port: Int {
        get {
            let prefs = Current.settingsStore.prefs
            guard prefs.object(forKey: UserDefaultsKeys.port.rawValue) != nil else { return 8090 }
            return prefs.integer(forKey: UserDefaultsKeys.port.rawValue)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.port.rawValue)
            queue.async { [weak self] in
                guard let self, active else { return }
                stopListener()
                // Restart on the new port after a beat, giving the cancelled listener
                // time to release its socket.
                queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self, active else { return }
                    startListener()
                    notifyStateChange()
                    Current.Log.info("Camera stream: restarted on port \(port)")
                }
            }
        }
    }

    /// Desired stream frame rate in frames per second. The shared capture session
    /// runs at the highest rate any active consumer needs, so this only raises the
    /// capture rate while the server is active.
    public var streamFrameRate: Double {
        get {
            let prefs = Current.settingsStore.prefs
            guard prefs.object(forKey: UserDefaultsKeys.frameRate.rawValue) != nil else { return 15.0 }
            return prefs.double(forKey: UserDefaultsKeys.frameRate.rawValue)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.frameRate.rawValue)
            Current.motionDetection.refreshFrameRate()
        }
    }

    /// Optional HTTP Basic auth credentials. When both are empty the stream is open
    /// to anyone on the network; setting either requires clients to authenticate.
    /// The password is kept in the Keychain rather than UserDefaults.
    public var username: String {
        get { Current.settingsStore.prefs.string(forKey: UserDefaultsKeys.username.rawValue) ?? "" }
        set { Current.settingsStore.prefs.set(newValue, forKey: UserDefaultsKeys.username.rawValue) }
    }

    public var password: String {
        get { keychain[Self.passwordKeychainKey] ?? "" }
        set { keychain[Self.passwordKeychainKey] = newValue.isEmpty ? nil : newValue }
    }

    // MARK: - Activation

    /// Turns the stream server on or off. While on, the listener accepts clients and
    /// the camera runs continuously (foreground only).
    public func setActive(_ newValue: Bool) {
        queue.async { [weak self] in
            guard let self, active != newValue else { return }
            active = newValue
            if newValue {
                startListener()
            } else {
                stopListener()
            }
            updateCameraObservation()
            notifyStateChange()
            // The capture rate depends on which consumers are active.
            Current.motionDetection.refreshFrameRate()
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

        // Read the HTTP request, enforce Basic auth if configured, then reply with the
        // multipart header and keep the connection open for frames.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self, error == nil else {
                connection.cancel()
                return
            }

            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard Self.isAuthorized(request: request, username: username, password: password) else {
                sendUnauthorized(on: connection)
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
                queue.async {
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

    // MARK: - Authentication

    /// Whether the request satisfies the configured credentials. With no username and
    /// no password set, every request is allowed.
    static func isAuthorized(request: String, username: String, password: String) -> Bool {
        guard !username.isEmpty || !password.isEmpty else { return true }
        guard let credentials = basicAuthCredentials(fromRequest: request) else { return false }
        return credentials.username == username && credentials.password == password
    }

    /// Extracts `(username, password)` from an `Authorization: Basic <base64>` header
    /// in the raw HTTP request, or `nil` when absent or malformed.
    static func basicAuthCredentials(fromRequest request: String) -> (username: String, password: String)? {
        for line in request.split(whereSeparator: { $0 == "\r" || $0 == "\n" }) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            guard name.caseInsensitiveCompare("Authorization") == .orderedSame else { continue }

            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            let scheme = "Basic "
            guard value.count > scheme.count, value.lowercased().hasPrefix(scheme.lowercased()) else { return nil }

            let encoded = value.dropFirst(scheme.count).trimmingCharacters(in: .whitespaces)
            guard let decodedData = Data(base64Encoded: encoded),
                  let decoded = String(data: decodedData, encoding: .utf8),
                  let separator = decoded.firstIndex(of: ":") else {
                return nil
            }
            return (String(decoded[..<separator]), String(decoded[decoded.index(after: separator)...]))
        }
        return nil
    }

    private func sendUnauthorized(on connection: NWConnection) {
        let response = [
            "HTTP/1.1 401 Unauthorized",
            "WWW-Authenticate: Basic realm=\"\(Self.authRealm)\"",
            "Content-Length: 0",
            "Connection: close",
            "",
            "",
        ].joined(separator: "\r\n")
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
        Current.Log.info("Camera stream: rejected unauthorized client")
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
            guard let self, !queue.sync(execute: { self.connections.isEmpty }) else { return }

            let image = CIImage(cvPixelBuffer: frame, options: [.colorSpace: Self.sdrColorSpace])
            guard let jpeg = ciContext.jpegRepresentation(
                of: image,
                colorSpace: Self.sdrColorSpace
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

            queue.async {
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
public class CameraStreamServer {
    public var onStateChange: (() -> Void)?
    public var isActive: Bool { false }
    public var isStreaming: Bool { false }
    public var clientCount: Int { 0 }
    public var port: Int = 8090
    public var streamFrameRate: Double = 15
    public var username: String = ""
    public var password: String = ""

    public init() {}

    public func setActive(_ newValue: Bool) {}
}

#endif
