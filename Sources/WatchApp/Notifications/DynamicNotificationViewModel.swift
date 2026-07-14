import Foundation
import MapKit
import PromiseKit
import Shared
import UIKit
import UserNotifications

@MainActor
final class DynamicNotificationViewModel: ObservableObject {
    enum Content {
        case image(UIImage)
        case map(primary: CLLocationCoordinate2D, secondary: CLLocationCoordinate2D?)
        case movie(URL)
    }

    @Published private(set) var title = ""
    @Published private(set) var subtitle = ""
    @Published private(set) var message = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var content: Content?

    private var api: HomeAssistantAPI?
    private var cameraEntityId: String?
    private var streamer: MJPEGStreamer?
    private var securityScopedURL: URL?

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    func didReceive(_ notification: UNNotification) {
        let notificationContent = notification.request.content

        reset()

        // Unlike iOS, the watch long-look does not show the app name near our custom
        // content, so a title-less payload would render as a bare message.
        title = notificationContent.title.isEmpty ? "Home Assistant" : notificationContent.title
        subtitle = notificationContent.subtitle
        message = notificationContent.body

        guard let server = Current.servers.server(for: notificationContent) else {
            return
        }

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to handle didReceive(_ notification: UNNotification)")
            return
        }

        self.api = api

        if let entityId = notificationContent.userInfo["entity_id"] as? String, entityId.starts(with: "camera.") {
            cameraEntityId = entityId
            startCameraStream()
        } else if let haDict = notificationContent.userInfo["homeassistant"] as? [String: Any],
                  let latitude = CLLocationDegrees(templateValue: haDict["latitude"]),
                  let longitude = CLLocationDegrees(templateValue: haDict["longitude"]) {
            let primary = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            let secondary: CLLocationCoordinate2D?
            if let secondLatitude = CLLocationDegrees(templateValue: haDict["second_latitude"]),
               let secondLongitude = CLLocationDegrees(templateValue: haDict["second_longitude"]) {
                secondary = CLLocationCoordinate2D(latitude: secondLatitude, longitude: secondLongitude)
            } else {
                secondary = nil
            }

            content = .map(primary: primary, secondary: secondary)
        } else if let attachmentURL = notificationContent.attachments.first?.url, showMedia(from: attachmentURL) {
            // attachment already provided with the notification
        } else {
            downloadAttachment(from: notificationContent, api: api)
        }
    }

    /// Restarts the camera stream when the interface re-activates after `pause()`.
    func resume() {
        if cameraEntityId != nil, streamer == nil {
            startCameraStream()
        }
    }

    func pause() {
        streamer?.cancel()
        streamer = nil
    }

    private func reset() {
        streamer?.cancel()
        streamer = nil
        cameraEntityId = nil
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        content = nil
        errorMessage = nil
        isLoading = false
    }

    private func startCameraStream() {
        guard let api, let cameraEntityId else { return }

        isLoading = true

        let streamer = api.VideoStreamer()
        self.streamer = streamer

        Task { [weak self] in
            guard let self else { return }

            guard let apiURL = await api.server.activeAPIURL() else {
                isLoading = false
                show(error: ServerConnectionError.noActiveURL(api.server.info.name))
                return
            }

            let queryURL = apiURL.appendingPathComponent("camera_proxy_stream/\(cameraEntityId)", isDirectory: false)

            streamer.streamImages(fromURL: queryURL) { [weak self] image, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.show(error: error)
                    } else if let image {
                        self.content = .image(image)
                    }
                }
            }
        }
    }

    private func downloadAttachment(from notificationContent: UNNotificationContent, api: HomeAssistantAPI) {
        isLoading = true

        Task {
            do {
                let url: URL = try await withCheckedThrowingContinuation { continuation in
                    Current.notificationAttachmentManager.downloadAttachment(from: notificationContent, api: api)
                        .done { continuation.resume(returning: $0) }
                        .catch { continuation.resume(throwing: $0) }
                }
                isLoading = false
                _ = showMedia(from: url)
            } catch {
                isLoading = false
                Current.Log.info("no attachments downloaded: \(error)")

                if (error as? NotificationAttachmentManagerServiceError) != .noAttachment {
                    show(error: error)
                }
            }
        }
    }

    private func showMedia(from url: URL) -> Bool {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        let data: Data

        do {
            // FB9096214 watchOS will give us a url which fails security scoped access and errors with
            // Error Domain=NSCocoaErrorDomain Code=257
            // so we unfortunately have to pretend like no attachment existed if we can't _read_ it
            data = try Data(contentsOf: url, options: .alwaysMapped)
        } catch {
            Current.Log.error("failed to open data: \(error) security scope happened \(didStartSecurityScope)")
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            return false
        }

        Current.Log.info("creating with url \(url) data size \(data.count)")

        if didStartSecurityScope {
            securityScopedURL = url
        }

        if let image = UIImage(data: data) {
            content = .image(image)
        } else {
            content = .movie(url)
        }

        return true
    }

    private func show(error: Error) {
        errorMessage = L10n.NotificationService.failedToLoad + "\n" + error.localizedDescription
    }
}

#if DEBUG
extension DynamicNotificationViewModel {
    static func preview(
        title: String = "",
        subtitle: String = "",
        message: String = "",
        isLoading: Bool = false,
        errorMessage: String? = nil,
        content: Content? = nil
    ) -> DynamicNotificationViewModel {
        let viewModel = DynamicNotificationViewModel()
        viewModel.title = title
        viewModel.subtitle = subtitle
        viewModel.message = message
        viewModel.isLoading = isLoading
        viewModel.errorMessage = errorMessage
        viewModel.content = content
        return viewModel
    }
}
#endif
