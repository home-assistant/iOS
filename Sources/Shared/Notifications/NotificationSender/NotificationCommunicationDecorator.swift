import Foundation
import ImageIO
@preconcurrency import Intents
import UIKit
import UserNotifications

public protocol NotificationCommunicationDecorator {
    func decorate(
        content: UNNotificationContent,
        sender: NotificationSenderInfo,
        api: HomeAssistantAPI?
    ) async -> UNNotificationContent
}

public final class NotificationCommunicationDecoratorImpl: NotificationCommunicationDecorator {
    private let cache: NotificationIconCache
    private let mdiImage: (String, UIColor, UIColor) -> INImage?

    public convenience init() {
        self.init(cache: NotificationIconCacheImpl())
    }

    init(
        cache: NotificationIconCache,
        mdiImage: @escaping (String, UIColor, UIColor) -> INImage? = NotificationCommunicationDecoratorImpl.makeMDIImage
    ) {
        self.cache = cache
        self.mdiImage = mdiImage
    }

    public func decorate(
        content: UNNotificationContent,
        sender: NotificationSenderInfo,
        api: HomeAssistantAPI?
    ) async -> UNNotificationContent {
        let intent = await buildIntent(sender: sender, title: sender.senderName, body: content.body, api: api)
        do {
            return try content.updating(from: intent)
        } catch {
            Current.Log.error("Communication notification updating(from:) failed: \(error)")
            return content
        }
    }

    func buildIntent(
        sender: NotificationSenderInfo,
        title: String,
        body: String,
        api: HomeAssistantAPI?
    ) async -> INSendMessageIntent {
        let image = await avatarImage(for: sender.source, api: api)
        let conversationID = conversationIdentifier(for: sender)
        let handle = INPersonHandle(value: conversationID, type: .unknown)
        var nameComponents = PersonNameComponents()
        nameComponents.nickname = title
        let person = INPerson(
            personHandle: handle,
            nameComponents: nameComponents,
            displayName: title,
            image: image,
            contactIdentifier: nil,
            customIdentifier: conversationID
        )
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: body,
            speakableGroupName: nil,
            conversationIdentifier: conversationID,
            serviceName: "HomeAssistant",
            sender: person,
            attachments: nil
        )
        await withCheckedContinuation { continuation in
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.direction = .incoming
            interaction.donate { error in
                if let error {
                    Current.Log.error("INInteraction donate failed: \(error)")
                }
                continuation.resume()
            }
        }
        return intent
    }

    private func avatarImage(
        for source: NotificationSenderInfo.Source,
        api: HomeAssistantAPI?
    ) async -> INImage? {
        switch source {
        case let .mdi(name, background, foreground, _, _):
            return mdiImage(name, foreground, background)
        case let .iconURL(url, needsAuth):
            let serverID = api?.server.identifier.rawValue
            let cacheKey = notificationIconCacheKey(for: url, serverID: serverID)
            if let cached = cache.data(forKey: cacheKey) {
                return INImage(imageData: cached)
            }
            guard let api else {
                Current.Log.error("Cannot download notification avatar without HomeAssistantAPI context")
                return nil
            }
            do {
                let downloadedFile = try await api.DownloadDataAt(url: url, needsAuth: needsAuth).asyncValue()
                defer {
                    try? FileManager.default.removeItem(at: downloadedFile)
                }
                guard let size = Self.fileSize(at: downloadedFile), size <= 5 * 1024 * 1024 else {
                    Current.Log.error("Downloaded avatar file is too large or size unknown: \(downloadedFile.path)")
                    return nil
                }
                guard let downsampled = Self.downsample(url: downloadedFile, maxDimension: 256) else {
                    Current.Log.error("Failed to decode/downsample downloaded avatar from \(downloadedFile.path)")
                    return nil
                }
                cache.setData(downsampled, forKey: cacheKey)
                return INImage(imageData: downsampled)
            } catch {
                Current.Log.error("Failed to download notification avatar from \(url): \(error)")
                return nil
            }
        }
    }

    private func conversationIdentifier(for sender: NotificationSenderInfo) -> String {
        let iconKey: String
        switch sender.source {
        case let .mdi(name, _, _, colorString, iconColorString):
            iconKey = "\(name)|\(colorString ?? "default")|\(iconColorString ?? "white")"
        case let .iconURL(url, _):
            iconKey = url.absoluteString
        }
        return "ha-sender:\(sender.senderName.lowercased()):\(iconKey)"
    }

    private static func fileSize(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }

    private static func makeMDIImage(name: String, foreground: UIColor, background: UIColor) -> INImage? {
        #if os(iOS)
        return INImage(
            icon: MaterialDesignIcons(serversideValueNamed: name, fallback: .bellIcon),
            foreground: foreground,
            background: background
        )
        #else
        return nil
        #endif
    }

    private static func downsample(url: URL, maxDimension: CGFloat) -> Data? {
        // Avoid caching the full decoded source within the notification service extension's memory limit.
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return nil
        }
        #if os(iOS)
        return UIImage(cgImage: thumbnail).pngData()
        #else
        return nil
        #endif
    }
}
