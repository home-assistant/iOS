import Foundation
import ImageIO
import Intents
import PromiseKit
import UIKit
import UserNotifications

public protocol NotificationCommunicationDecorator {
    func decorate(
        content: UNNotificationContent,
        sender: NotificationSenderInfo,
        api: HomeAssistantAPI?
    ) -> Guarantee<UNNotificationContent>
}

public final class NotificationCommunicationDecoratorImpl: NotificationCommunicationDecorator {
    private let cache: NotificationIconCache

    public convenience init() {
        self.init(cache: NotificationIconCacheImpl())
    }

    init(cache: NotificationIconCache) {
        self.cache = cache
    }

    public func decorate(
        content: UNNotificationContent,
        sender: NotificationSenderInfo,
        api: HomeAssistantAPI?
    ) -> Guarantee<UNNotificationContent> {
        let title = content.title
        guard !title.isEmpty else { return .value(content) }

        return buildIntent(sender: sender, title: title, body: content.body, api: api)
            .map { intent in
                do {
                    return try content.updating(from: intent)
                } catch {
                    Current.Log.error("Communication notification updating(from:) failed: \(error)")
                    return content
                }
            }
    }

    /// Internal so tests can drive it directly. Returns `Guarantee` because failures
    /// always fall back to a best-effort intent rather than rejecting the pipeline.
    func buildIntent(
        sender: NotificationSenderInfo,
        title: String,
        body: String,
        api: HomeAssistantAPI?
    ) -> Guarantee<INSendMessageIntent> {
        avatarImage(for: sender.source, api: api).then { [self] image -> Guarantee<INSendMessageIntent> in
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
            return Guarantee { seal in
                let interaction = INInteraction(intent: intent, response: nil)
                interaction.direction = .incoming
                interaction.donate { error in
                    if let error { Current.Log.error("INInteraction donate failed: \(error)") }
                    seal(intent)
                }
            }
        }
    }

    /// MDI path is synchronous (no network). URL path downloads, caches, and downsamples the avatar.
    private func avatarImage(
        for source: NotificationSenderInfo.Source,
        api: HomeAssistantAPI?
    ) -> Guarantee<INImage?> {
        switch source {
        case let .mdi(name, background, foreground, _, _):
            #if os(iOS)
            let image = INImage(
                icon: MaterialDesignIcons(serversideValueNamed: name, fallback: .bellIcon),
                foreground: foreground,
                background: background
            )
            return .value(image)
            #else
            return .value(nil)
            #endif
        case let .iconURL(url, needsAuth):
            let serverID = api?.server.identifier.rawValue
            let cacheKey = notificationIconCacheKey(for: url, serverID: serverID)
            if let cached = cache.data(forKey: cacheKey) {
                return .value(INImage(imageData: cached))
            }
            guard let api else {
                Current.Log.error("Cannot download notification avatar without HomeAssistantAPI context")
                return .value(nil)
            }
            return Guarantee { seal in
                api.DownloadDataAt(url: url, needsAuth: needsAuth).done { [cache] downloadedFile in
                    defer {
                        try? FileManager.default.removeItem(at: downloadedFile)
                    }
                    guard let size = Self.fileSize(at: downloadedFile), size <= 5 * 1024 * 1024 else {
                        Current.Log.error("Downloaded avatar file is too large or size unknown: \(downloadedFile.path)")
                        seal(nil); return
                    }
                    guard let downsampled = Self.downsample(url: downloadedFile, maxDimension: 256) else {
                        Current.Log.error("Failed to decode/downsample downloaded avatar from \(downloadedFile.path)")
                        seal(nil); return
                    }
                    cache.setData(downsampled, forKey: cacheKey)
                    seal(INImage(imageData: downsampled))
                }.catch { error in
                    Current.Log.error("Failed to download notification avatar from \(url): \(error)")
                    seal(nil)
                }
            }
        }
    }

    /// Returns a stable, human-readable conversation identifier so iOS groups successive
    /// notifications from the same automation. Kept as a raw string (no hashing) so it can
    /// be eyeballed in logs and Siri suggestion dumps when diagnosing grouping issues.
    /// The `|` separator cannot appear in MDI names or 6-digit hex strings, so collisions
    /// across distinct inputs are not possible.
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

    /// Reduce the source image to at most `maxDimension` px on the longer side, returning
    /// fresh PNG bytes suitable for `INImage(imageData:)`. Returns `nil` if the image
    /// isn't a decodable format.
    ///
    /// ImageIO option choice (these operate at different levels):
    /// - `kCGImageSourceShouldCache: false` on the SOURCE: ImageIO must not cache the full
    ///   decoded source pixels in its tile store. Critical for staying under the NSE's
    ///   ~24 MB ceiling when the source happens to be a large JPEG/PNG.
    /// - `kCGImageSourceShouldCacheImmediately: true` on the THUMBNAIL: decode the small
    ///   thumbnail eagerly rather than lazily, so the bitmap is realised here under our
    ///   memory budget rather than later inside the Intents framework.
    ///
    /// `INImage` has no `init(cgImage:)`, so we round-trip back through PNG bytes.
    private static func downsample(url: URL, maxDimension: CGFloat) -> Data? {
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
