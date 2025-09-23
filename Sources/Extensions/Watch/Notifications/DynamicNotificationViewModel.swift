import AVFoundation
import AVKit
import MapKit
import PromiseKit
import Shared
import SwiftUI
import UserNotifications

final class DynamicNotificationViewModel: ObservableObject {
    enum DynamicContent {
        case none
        case image(UIImage)
        case video(URL)
        case map(region: MKCoordinateRegion, pins: [CLLocationCoordinate2D])
    }

    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var body: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var content: DynamicContent = .none

    private var streamer: MJPEGStreamer?
    private var securityScopedURL: URL?

    deinit {
        stop()
    }

    func stop() {
        streamer?.cancel()
        streamer = nil
        if let securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
            self.securityScopedURL = nil
        }
    }

    func configure(from notification: UNNotification, api: HomeAssistantAPI) {
        DispatchQueue.main.async {
            self.title = notification.request.content.title
            self.subtitle = notification.request.content.subtitle
            self.body = notification.request.content.body
            self.errorMessage = nil
            self.content = .none
            self.isLoading = true
        }

        // Try MJPEG camera first (mirrors NotificationSubControllerMJPEG)
        if let entityId = (notification.request.content.userInfo["entity_id"] as? String),
           entityId.starts(with: "camera.") {
            startMJPEG(entityId: entityId, api: api)
            return
        }

        // Try Map (mirrors NotificationSubControllerMap)
        if let ha = notification.request.content.userInfo["homeassistant"] as? [String: Any],
           let lat = Self.parseDegrees(ha["latitude"]),
           let lon = Self.parseDegrees(ha["longitude"]) {
            let primary = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            var pins = [primary]

            if let sLat = Self.parseDegrees(ha["second_latitude"]),
               let sLon = Self.parseDegrees(ha["second_longitude"]) {
                pins.append(CLLocationCoordinate2D(latitude: sLat, longitude: sLon))
            }

            let region = Self.region(for: pins)
            DispatchQueue.main.async {
                self.content = .map(region: region, pins: pins)
                self.isLoading = false
            }
            return
        }

        // Try media attachment already present (mirrors NotificationSubControllerMedia)
        if let url = notification.request.content.attachments.first?.url {
            handleMediaURL(url)
            return
        }

        // Fallback: download attachment via manager
        let content = notification.request.content
        firstly {
            Current.notificationAttachmentManager.downloadAttachment(from: content, api: api)
        }.done { [weak self] url in
            self?.handleMediaURL(url)
        }.catch { [weak self] error in
            // Allow "noAttachment" to simply render text; show others as errors
            if case NotificationAttachmentManagerServiceError.noAttachment = error {
                // no-op, we’ll leave the text-only content
            } else {
                DispatchQueue.main.async {
                    self?.errorMessage = L10n.NotificationService.failedToLoad + "\n" + error.localizedDescription
                }
            }
        }.finally { [weak self] in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
        }
    }

    private func startMJPEG(entityId: String, api: HomeAssistantAPI) {
        let streamer = api.VideoStreamer()
        self.streamer = streamer

        guard let apiURL = api.server.info.connection.activeAPIURL() else {
            DispatchQueue.main.async {
                self.errorMessage = HomeAssistantAPI.APIError.cantBuildURL.localizedDescription
                self.isLoading = false
            }
            return
        }

        let url = apiURL.appendingPathComponent("camera_proxy_stream/\(entityId)", isDirectory: false)

        streamer.streamImages(fromURL: url) { [weak self] image, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                return
            }
            if let image {
                DispatchQueue.main.async {
                    // Fulfill on first frame; subsequent frames will continue updating the image.
                    self.content = .image(image)
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Media handling

    private func handleMediaURL(_ url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        if didStart {
            securityScopedURL = url
        }

        if let img = UIImage(contentsOfFile: url.path) {
            DispatchQueue.main.async {
                self.content = .image(img)
                self.isLoading = false
            }
        } else {
            DispatchQueue.main.async {
                self.content = .video(url)
                self.isLoading = false
            }
        }
    }

    // MARK: - Map functions

    private static func parseDegrees(_ any: Any?) -> CLLocationDegrees? {
        if let d = any as? Double { return d }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String, let d = Double(s) { return d }
        return nil
    }

    private static func region(for pins: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = pins.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        if pins.count == 1 {
            return MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        var minLat: CLLocationDegrees = 90.0
        var maxLat: CLLocationDegrees = -90.0
        var minLon: CLLocationDegrees = 180.0
        var maxLon: CLLocationDegrees = -180.0

        for c in pins {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 2.0,
            longitudeDelta: (maxLon - minLon) * 2.0
        )
        let center = CLLocationCoordinate2D(
            latitude: maxLat - span.latitudeDelta / 4,
            longitude: maxLon - span.longitudeDelta / 4
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
