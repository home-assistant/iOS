import AudioToolbox
import AVKit
import Combine
import Shared
import SwiftUI

// MARK: - Camera Overlay View

/// A Picture-in-Picture style camera overlay for doorbell/security camera events
public struct CameraOverlayView: View {
    @ObservedObject private var manager = CameraOverlayManager.shared

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            if manager.isVisible, let stream = manager.currentStream {
                // Semi-transparent background that dismisses on tap
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        manager.dismiss()
                    }

                cameraContent(stream: stream, in: geometry)
                    .position(overlayPosition(in: geometry))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(), value: manager.isVisible)
            }
        }
        .allowsHitTesting(manager.isVisible)
    }

    @ViewBuilder
    private func cameraContent(stream: CameraStream, in geometry: GeometryProxy) -> some View {
        let size = overlaySize(in: geometry)

        VStack(spacing: 0) {
            // Header with camera name and dismiss
            headerView(stream: stream)

            // Camera stream - fills width, fixed height based on aspect ratio
            CameraStreamView(stream: stream)
                .frame(height: size.height)
                .clipped()

            // Action buttons
            if stream.showActions {
                actionButtons(stream: stream)
            }
        }
        .frame(width: size.width)  // Constrain entire container width
        .background(Color.black)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func headerView(stream: CameraStream) -> some View {
        HStack {
            // Camera icon
            Image(systemName: stream.type == .doorbell ? "video.doorbell" : "video")
                .font(.caption)
                .foregroundColor(.white)
                .accessibilityHidden(true) // Name is read separately

            // Camera name
            Text(stream.name)
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .accessibilityLabel("Camera: \(stream.name)")

            Spacer()

            // Expand button
            Button {
                manager.expandToFullScreen()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .accessibilityLabel("Expand to full screen")
            .padding(.trailing, 4)

            // Dismiss button
            Button {
                manager.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
            }
            .accessibilityLabel("Dismiss camera")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
    }

    private func actionButtons(stream: CameraStream) -> some View {
        VStack(spacing: 8) {
            // Standard action buttons row
            HStack(spacing: 12) {
                if stream.type == .doorbell {
                    // Answer/talk button for doorbell
                    Button {
                        manager.answerDoorbell()
                    } label: {
                        Label("Talk", systemImage: "mic.fill")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(6)
                    }

                    // Unlock button (if configured)
                    if stream.unlockEntityId != nil {
                        Button {
                            manager.unlock()
                        } label: {
                            Label("Unlock", systemImage: "lock.open.fill")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                    }
                }

                // Snapshot button
                Button {
                    manager.takeSnapshot()
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .accessibilityLabel("Take snapshot")
            }

            // Custom action buttons (if any)
            if let customActions = stream.customActions, !customActions.isEmpty {
                customActionButtons(actions: customActions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
    }

    private func customActionButtons(actions: [CameraStream.CameraAction]) -> some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                Button {
                    manager.executeAction(action)
                } label: {
                    Label(action.label, systemImage: action.sfSymbol)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Layout

    private func overlaySize(in geometry: GeometryProxy) -> CGSize {
        let sizeSettings = KioskModeManager.shared.settings.cameraPopupSize.sizeParameters
        let maxWidth = geometry.size.width * sizeSettings.widthPercent
        let maxHeight = geometry.size.height * sizeSettings.heightPercent
        let aspectRatio: CGFloat = 16 / 9

        var width = min(maxWidth, sizeSettings.maxWidth)
        var height = width / aspectRatio

        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }

        return CGSize(width: width, height: height)
    }

    private func overlayPosition(in geometry: GeometryProxy) -> CGPoint {
        let position = KioskModeManager.shared.settings.cameraPopupPosition
        let size = overlaySize(in: geometry)
        let padding: CGFloat = 20

        switch position {
        case .center:
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        case .topLeft:
            return CGPoint(x: size.width / 2 + padding, y: size.height / 2 + padding + 60) // 60 for header
        case .topRight:
            return CGPoint(x: geometry.size.width - size.width / 2 - padding, y: size.height / 2 + padding + 60)
        case .bottomLeft:
            return CGPoint(x: size.width / 2 + padding, y: geometry.size.height - size.height / 2 - padding - 40) // 40 for actions
        case .bottomRight:
            return CGPoint(x: geometry.size.width - size.width / 2 - padding, y: geometry.size.height - size.height / 2 - padding - 40)
        }
    }

}

// MARK: - Camera Stream View

/// Displays a camera stream using HLS or MJPEG with proper Home Assistant authentication
struct CameraStreamView: UIViewRepresentable {
    let stream: CameraStream

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black

        // Create image view for displaying stream frames
        let imageView = UIImageView(frame: containerView.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Add loading indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.center = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
        activityIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)
        context.coordinator.activityIndicator = activityIndicator

        // Start the appropriate stream
        if stream.streamType == .hls, let hlsURL = stream.hlsURL {
            // Use AVPlayer for HLS
            let player = AVPlayer(url: hlsURL)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = containerView.bounds
            playerLayer.videoGravity = .resizeAspect
            containerView.layer.insertSublayer(playerLayer, at: 0)
            player.play()

            context.coordinator.player = player
            context.coordinator.playerLayer = playerLayer
            activityIndicator.stopAnimating()
        } else if let mjpegPath = stream.mjpegPath {
            // Use MJPEGStreamer with proper authentication
            startMJPEGStream(path: mjpegPath, coordinator: context.coordinator)
        }

        return containerView
    }

    private func startMJPEGStream(path: String, coordinator: Coordinator) {
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server),
              let url = api.server.info.connection.activeURL()?.appendingPathComponent(path) else {
            Current.Log.error("Cannot start MJPEG stream: no server connection or invalid path")
            coordinator.activityIndicator?.stopAnimating()
            return
        }

        // Create MJPEGStreamer with proper authentication via the API
        let streamer = api.VideoStreamer()
        coordinator.streamer = streamer

        Current.Log.info("Starting MJPEG stream from: \(url.absoluteString)")

        streamer.streamImages(fromURL: url) { [weak coordinator] image, error in
            guard let coordinator = coordinator else { return }

            coordinator.activityIndicator?.stopAnimating()

            if let error = error {
                Current.Log.error("MJPEG stream error: \(error.localizedDescription)")
                return
            }

            if let image = image {
                coordinator.imageView?.image = image
            }
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
        context.coordinator.imageView?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var imageView: UIImageView?
        var streamer: MJPEGStreamer?
        var activityIndicator: UIActivityIndicatorView?

        deinit {
            player?.pause()
            streamer?.cancel()
        }
    }
}

// MARK: - Camera Stream Model

public struct CameraStream: Identifiable {
    public let id: String
    public let name: String
    public let entityId: String
    public let type: CameraType
    public let streamType: StreamType
    public let hlsURL: URL?
    /// The MJPEG stream path (relative to HA base URL), e.g. "/api/camera_proxy_stream/camera.front_door"
    public let mjpegPath: String?
    public let showActions: Bool
    public let unlockEntityId: String?
    public let autoDismissSeconds: TimeInterval?
    /// Alert sound to play when popup appears
    public let alertSound: AlertSound?
    /// Volume for alert sound (0.0 - 1.0)
    public let alertVolume: Float?
    /// Custom action buttons to display
    public let customActions: [CameraAction]?

    public enum CameraType {
        case doorbell
        case security
        case generic
    }

    public enum StreamType {
        case hls
        case mjpeg
    }

    /// Predefined alert sounds for camera popup
    public enum AlertSound: String, CaseIterable {
        case none
        case doorbellClassic = "doorbell_classic"
        case doorbellChime = "doorbell_chime"
        case doorbellMelody = "doorbell_melody"
        case motionSubtle = "motion_subtle"
        case motionAlert = "motion_alert"
        case securityUrgent = "security_urgent"

        /// System sound ID for playback
        var systemSoundID: UInt32? {
            switch self {
            case .none: return nil
            case .doorbellClassic: return 1315 // Mail sent
            case .doorbellChime: return 1314 // Tweet
            case .doorbellMelody: return 1309 // Anticipate
            case .motionSubtle: return 1057 // Tink
            case .motionAlert: return 1007 // SMS received
            case .securityUrgent: return 1005 // Alarm
            }
        }

        var displayName: String {
            switch self {
            case .none: return "None"
            case .doorbellClassic: return "Classic Doorbell"
            case .doorbellChime: return "Chime"
            case .doorbellMelody: return "Melody"
            case .motionSubtle: return "Subtle"
            case .motionAlert: return "Alert"
            case .securityUrgent: return "Urgent"
            }
        }
    }

    /// Custom action button for camera popup
    public struct CameraAction: Identifiable {
        public let id: String
        public let label: String
        public let icon: String?
        public let service: String
        public let target: [String: Any]?
        public let serviceData: [String: Any]?
        public let confirmRequired: Bool

        public init(
            id: String = UUID().uuidString,
            label: String,
            icon: String? = nil,
            service: String,
            target: [String: Any]? = nil,
            serviceData: [String: Any]? = nil,
            confirmRequired: Bool = false
        ) {
            self.id = id
            self.label = label
            self.icon = icon
            self.service = service
            self.target = target
            self.serviceData = serviceData
            self.confirmRequired = confirmRequired
        }

        /// SF Symbol name for common icons
        var sfSymbol: String {
            guard let icon = icon else { return "questionmark.circle" }

            // Map common MDI icons to SF Symbols
            switch icon.lowercased().replacingOccurrences(of: "mdi:", with: "") {
            case "lightbulb", "lightbulb-on": return "lightbulb.fill"
            case "lightbulb-off": return "lightbulb"
            case "lock": return "lock.fill"
            case "lock-open", "lock-open-variant": return "lock.open.fill"
            case "bullhorn", "megaphone": return "megaphone.fill"
            case "message", "chat": return "message.fill"
            case "bell", "bell-ring": return "bell.fill"
            case "door", "door-open": return "door.left.hand.open"
            case "garage", "garage-open": return "rectangle.split.3x1"
            case "fan": return "fan.fill"
            case "thermostat": return "thermometer"
            case "camera": return "camera.fill"
            case "motion-sensor": return "figure.walk"
            case "power": return "power"
            case "play": return "play.fill"
            case "stop": return "stop.fill"
            default: return "questionmark.circle"
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        entityId: String,
        type: CameraType = .generic,
        streamType: StreamType = .mjpeg,
        hlsURL: URL? = nil,
        mjpegPath: String? = nil,
        showActions: Bool = false,
        unlockEntityId: String? = nil,
        autoDismissSeconds: TimeInterval? = nil,
        alertSound: AlertSound? = nil,
        alertVolume: Float? = nil,
        customActions: [CameraAction]? = nil
    ) {
        self.id = id
        self.name = name
        self.entityId = entityId
        self.type = type
        self.streamType = streamType
        self.hlsURL = hlsURL
        self.mjpegPath = mjpegPath
        self.showActions = showActions
        self.unlockEntityId = unlockEntityId
        self.autoDismissSeconds = autoDismissSeconds
        self.alertSound = alertSound
        self.alertVolume = alertVolume
        self.customActions = customActions
    }
}

// MARK: - Camera Overlay Manager

@MainActor
public final class CameraOverlayManager: ObservableObject {
    public static let shared = CameraOverlayManager()

    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var currentStream: CameraStream?

    public var onExpandToFullScreen: ((CameraStream) -> Void)?
    public var onDismiss: (() -> Void)?

    private var autoDismissTask: Task<Void, Never>?

    private init() {}

    public func show(stream: CameraStream) {
        currentStream = stream
        isVisible = true

        // Play alert sound if configured
        playAlertSound(stream: stream)

        // Auto-dismiss if configured
        if let seconds = stream.autoDismissSeconds {
            autoDismissTask?.cancel()
            autoDismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.dismiss()
            }
        }

        Current.Log.info("Showing camera overlay: \(stream.name)")
    }

    private func playAlertSound(stream: CameraStream) {
        guard let sound = stream.alertSound, sound != .none else { return }
        guard let soundID = sound.systemSoundID else { return }

        // Set volume if specified
        if let volume = stream.alertVolume {
            // Note: System sounds respect device volume, can't set directly
            // but we log it for debugging
            Current.Log.verbose("Playing alert sound \(sound.rawValue) (volume hint: \(volume))")
        }

        AudioServicesPlaySystemSound(SystemSoundID(soundID))
        Current.Log.info("Playing alert sound: \(sound.displayName)")
    }

    public func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        isVisible = false
        currentStream = nil
        onDismiss?()

        Current.Log.info("Camera overlay dismissed")
    }

    public func expandToFullScreen() {
        guard let stream = currentStream else { return }
        dismiss()
        onExpandToFullScreen?(stream)
    }

    public func answerDoorbell() {
        guard let stream = currentStream else { return }
        Current.Log.info("Answer doorbell: \(stream.name)")

        // Start two-way audio session
        // This requires a configured media player entity for audio output
        // and microphone access for input
        Task {
            await startTwoWayAudio(for: stream)
        }
    }

    private func startTwoWayAudio(for stream: CameraStream) async {
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.error("No HA connection for two-way audio")
            return
        }

        // If stream has an associated media player for audio output, use it
        // Otherwise, attempt to use the camera's built-in speaker if supported
        let targetEntity = stream.unlockEntityId?.replacingOccurrences(of: "lock.", with: "media_player.")
            ?? stream.entityId.replacingOccurrences(of: "camera.", with: "media_player.")

        // For cameras that support two-way audio (like some Nest/Ring cameras),
        // we would need WebRTC. For now, we provide TTS feedback through a media player.
        // Full WebRTC two-way audio would require additional native implementation.

        Current.Log.info("Two-way audio initiated for: \(stream.name)")

        // Notify that doorbell was answered (for automations)
        _ = try? await api.connection.send(.init(
            type: "fire_event",
            data: [
                "event_type": "kiosk_doorbell_answered",
                "event_data": [
                    "camera_entity_id": stream.entityId,
                    "stream_name": stream.name,
                ],
            ]
        )).promise.value

        // Play a notification sound/message if media player is available
        _ = try? await api.connection.send(.init(
            type: "call_service",
            data: [
                "domain": "tts",
                "service": "speak",
                "target": ["entity_id": targetEntity],
                "service_data": [
                    "message": "Someone is at the door and viewing the camera.",
                ],
            ]
        )).promise.value
    }

    public func unlock() {
        guard let stream = currentStream,
              let unlockEntityId = stream.unlockEntityId else { return }

        Current.Log.info("Unlock: \(unlockEntityId)")

        // Call HA service to unlock
        Task {
            guard let server = Current.servers.all.first,
                  let api = Current.api(for: server) else { return }

            let domain = unlockEntityId.split(separator: ".").first ?? "lock"
            _ = try? await api.connection.send(.init(
                type: "call_service",
                data: [
                    "domain": String(domain),
                    "service": "unlock",
                    "target": ["entity_id": unlockEntityId],
                ]
            )).promise.value
        }
    }

    /// Execute a custom action defined in the camera popup
    public func executeAction(_ action: CameraStream.CameraAction) {
        Current.Log.info("Executing custom action: \(action.label) -> \(action.service)")

        Task {
            await callService(action: action)
        }
    }

    private func callService(action: CameraStream.CameraAction) async {
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.error("No HA connection for custom action")
            return
        }

        // Parse domain and service from "domain.service" format
        let parts = action.service.split(separator: ".")
        guard parts.count == 2 else {
            Current.Log.error("Invalid service format: \(action.service). Expected 'domain.service'")
            return
        }

        let domain = String(parts[0])
        let service = String(parts[1])

        var data: [String: Any] = [
            "domain": domain,
            "service": service,
        ]

        // Add target if specified
        if let target = action.target {
            data["target"] = target
        }

        // Add service data if specified
        if let serviceData = action.serviceData {
            data["service_data"] = serviceData
        }

        do {
            _ = try await api.connection.send(.init(
                type: "call_service",
                data: data
            )).promise.value
            Current.Log.info("Custom action completed: \(action.label)")
        } catch {
            Current.Log.error("Custom action failed: \(error.localizedDescription)")
        }
    }

    public func takeSnapshot() {
        guard let stream = currentStream else { return }
        Current.Log.info("Take snapshot: \(stream.name)")

        Task {
            await captureSnapshot(for: stream)
        }
    }

    private func captureSnapshot(for stream: CameraStream) async {
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.error("No HA connection for snapshot")
            return
        }

        // Generate unique filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "/config/www/snapshots/\(stream.id)_\(timestamp).jpg"

        do {
            _ = try await api.connection.send(.init(
                type: "call_service",
                data: [
                    "domain": "camera",
                    "service": "snapshot",
                    "target": ["entity_id": stream.entityId],
                    "service_data": ["filename": filename],
                ]
            )).promise.value

            Current.Log.info("Snapshot saved: \(filename)")

            // Fire event for automations
            _ = try? await api.connection.send(.init(
                type: "fire_event",
                data: [
                    "event_type": "kiosk_snapshot_taken",
                    "event_data": [
                        "camera_entity_id": stream.entityId,
                        "filename": filename,
                    ],
                ]
            )).promise.value
        } catch {
            Current.Log.error("Failed to take snapshot: \(error.localizedDescription)")
        }
    }
}

// MARK: - Camera Overlay Passthrough View

/// Custom UIView that only intercepts touches when the camera overlay is visible
public final class CameraOverlayPassthroughView: UIView {
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Only intercept touches when the overlay is visible
        guard CameraOverlayManager.shared.isVisible else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

/// UIViewController that hosts CameraOverlayView with proper touch passthrough
public final class CameraOverlayViewController: UIViewController {
    private var hostingController: UIHostingController<CameraOverlayView>?

    public override func loadView() {
        view = CameraOverlayPassthroughView()
        view.backgroundColor = .clear
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let overlayView = CameraOverlayView()
        let hosting = UIHostingController(rootView: overlayView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    ZStack {
        Color.gray.edgesIgnoringSafeArea(.all)

        CameraOverlayView()
            .onAppear {
                CameraOverlayManager.shared.show(stream: CameraStream(
                    name: "Front Door",
                    entityId: "camera.front_door",
                    type: .doorbell,
                    streamType: .mjpeg,
                    mjpegPath: "/api/camera_proxy_stream/camera.front_door",
                    showActions: true,
                    unlockEntityId: "lock.front_door",
                    autoDismissSeconds: 30
                ))
            }
    }
}
