//
//  DynamicNotificationViewModel.swift
//  WatchApp
//
//  Created by Bruno Pantaleão on 22/9/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit
import MapKit
import Shared
import PromiseKit
import AVFoundation

enum DynamicContent {
    case none
    case image(UIImage)
    case map(region: MKCoordinateRegion, pins: [MKPointAnnotation])
    case video(url: URL)
    case mpegVideo(imageStream: (@escaping (UIImage) -> Void) -> Void)
    case error
}

final class DynamicNotificationViewModel: ObservableObject {

    @Published var title: String?
    @Published var subtitle: String?
    @Published var bodyText: String = ""
    @Published var isLoading: Bool = false
    @Published var dynamicContent: DynamicContent?
    @Published var errorMessage: String?

    @Published var videoPlayer = AVPlayer()

    private var activeAdapter: NotificationSubController?
    private var possibleSubControllers: [NotificationSubController.Type] { [
        NotificationSubControllerMJPEG.self,
        NotificationSubControllerMap.self,
        NotificationSubControllerMedia.self,
    ] }

    func handle(notification: UNNotification) {
        // Static labels
        title = notification.request.content.title
        subtitle = notification.request.content.subtitle
        bodyText = notification.request.content.body

        guard let server = Current.servers.server(for: notification.request.content) else {
            return
        }

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to handle didReceive(_ notification: UNNotification)")
            return
        }

        // Try to create a subcontroller directly from the notification
        if let adapter = adapter(for: notification, api: api) {
            start(adapter: adapter)
            return
        }

        // Otherwise, download attachment and try again with URL
        isLoading = true
        Current.notificationAttachmentManager
            .downloadAttachment(from: notification.request.content, api: api)
            .map { [weak self] url -> NotificationSubController? in
                guard let self else { return nil }
                return self.adapter(for: url, api: api)
            }
            .done { [weak self] adapter in
                guard let self else { return }
                if let adapter {
                    self.start(adapter: adapter)
                } else {
                    self.isLoading = false
                }
            }
            .catch { [weak self] error in
                guard let self else { return }
                Current.Log.info("no attachments downloaded: \(error)")
                if let svcError = error as? NotificationAttachmentManagerServiceError,
                   svcError == .noAttachment {
                    // ignore; just show text
                } else {
                    self.errorMessage = L10n.NotificationService.failedToLoad + "\n" + error.localizedDescription
                }
                self.isLoading = false
            }
    }

    private func adapter(for notification: UNNotification, api: HomeAssistantAPI) -> NotificationSubController? {
        for potential in possibleSubControllers {
            if let controller = potential.init(api: api, notification: notification) {
                return controller
            }
        }

        return nil
    }

    private func adapter(for url: URL, api: HomeAssistantAPI) -> NotificationSubController? {
        for potential in possibleSubControllers {
            if let controller = potential.init(api: api, url: url) {
                return controller
            }
        }

        return nil
    }

    private func start(adapter: NotificationSubController) {
        // Stop any previous
        activeAdapter?.stop()
        activeAdapter = adapter
        isLoading = true
        DispatchQueue.main.async { [weak self] in
            self?.dynamicContent = adapter.start()
        }
        self.isLoading = false
    }

    deinit {
        activeAdapter?.stop()
    }
}

