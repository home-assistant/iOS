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

    /// How far a text-input action has got, so the row can show progress without a second screen.
    enum TextInputActionState: Equatable {
        case sending
        case sent
        case failed
    }

    @Published private(set) var title = ""
    @Published private(set) var subtitle = ""
    @Published private(set) var message = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var content: Content?

    /// The text-input actions the long look renders itself rather than leaving to watchOS, keyed in
    /// `textInputActionStates` by `NotificationAction.id`. See `DynamicNotificationHostingController`.
    @Published private(set) var textInputActions: [NotificationAction] = []
    @Published private(set) var textInputActionStates: [String: TextInputActionState] = [:]

    /// Supplied by the hosting controller: presents watchOS's own text entry (dictation, scribble,
    /// keyboard) and calls back with what the user wrote, or `nil` if they backed out. Main-actor
    /// bound because presenting it is a `WKInterfaceController` call.
    var presentTextInput: (@MainActor (@escaping (String?) -> Void) -> Void)?

    private var api: HomeAssistantAPI?
    private var server: Server?
    private var notificationContent: UNNotificationContent?
    private var notificationIdentifier: String?
    private var cameraEntityId: String?
    private var streamer: MJPEGStreamer?
    private var securityScopedURL: URL?

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    func didReceive(_ notification: UNNotification, textInputActions: [NotificationAction] = []) {
        let notificationContent = notification.request.content

        reset()

        // Unlike iOS, the watch long-look does not show the app name near our custom
        // content, so a title-less payload would render as a bare message.
        title = notificationContent.title.isEmpty ? "Home Assistant" : notificationContent.title
        subtitle = notificationContent.subtitle
        message = notificationContent.body
        self.notificationContent = notificationContent
        notificationIdentifier = notification.request.identifier

        guard let server = Current.servers.server(for: notificationContent) else {
            return
        }

        self.server = server
        // Kept even when the API below is missing: a reply still reaches Home Assistant through the
        // paired iPhone, which is the usual case when the watch has no API of its own.
        self.textInputActions = textInputActions

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

    /// Asks the user for a reply and fires the notification action with it. This exists because
    /// watchOS drops text-input responses for forwarded notifications — see
    /// `DynamicNotificationHostingController.didReceive(_:)`.
    func perform(textInputAction action: NotificationAction) {
        guard let presentTextInput, let notificationContent, let server else {
            Current.Log.error("no way to collect a reply for \(action.identifier)")
            return
        }

        presentTextInput { [weak self] text in
            Task { @MainActor in
                // Only `nil` means the user backed out. An empty reply is a reply, and the system
                // response path forwards it too (`UNTextInputNotificationResponse.userText` is
                // non-optional), so dropping it here would silently swallow the event.
                guard let text else { return }
                self?.send(textInputAction: action, text: text, content: notificationContent, server: server)
            }
        }
    }

    private func send(
        textInputAction action: NotificationAction,
        text: String,
        content: UNNotificationContent,
        server: Server
    ) {
        textInputActionStates[action.id] = .sending

        let info = HomeAssistantAPI.PushActionInfo(
            content: content,
            actionIdentifier: action.identifier,
            textInput: text
        )

        Task { [weak self] in
            do {
                try await WatchPushActionSender.send(info, server: server)
                self?.didSend(textInputAction: action)
            } catch {
                Current.Log.error("failed to send notification text input action: \(error)")
                self?.textInputActionStates[action.id] = .failed
            }
        }
    }

    /// Marks the reply delivered and clears the notification, matching what the system does once an
    /// action is chosen so it does not sit in Notification Center already answered.
    private func didSend(textInputAction action: NotificationAction) {
        textInputActionStates[action.id] = .sent

        guard let notificationIdentifier else { return }
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
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
        api = nil
        server = nil
        notificationContent = nil
        notificationIdentifier = nil
        textInputActions = []
        textInputActionStates = [:]
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
        content: Content? = nil,
        textInputActions: [NotificationAction] = [],
        textInputActionStates: [String: TextInputActionState] = [:]
    ) -> DynamicNotificationViewModel {
        let viewModel = DynamicNotificationViewModel()
        viewModel.title = title
        viewModel.subtitle = subtitle
        viewModel.message = message
        viewModel.isLoading = isLoading
        viewModel.errorMessage = errorMessage
        viewModel.content = content
        viewModel.textInputActions = textInputActions
        viewModel.textInputActionStates = textInputActionStates
        return viewModel
    }
}
#endif
