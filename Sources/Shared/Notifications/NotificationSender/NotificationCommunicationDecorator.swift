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
        api: HomeAssistantAPI
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
        api: HomeAssistantAPI
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
        api: HomeAssistantAPI
    ) -> Guarantee<INSendMessageIntent> {
        avatarImage(for: sender.source, api: api).map { [self] image in
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
            // Donate before returning so that `decorate`'s subsequent call to
            // `content.updating(from:)` can associate this notification with the
            // conversation. Donation is a global system side-effect (visible in Siri
            // suggestions); failures here are logged but never block notification
            // delivery, since the styling still applies without the donation.
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.direction = .incoming
            interaction.donate { error in
                if let error { Current.Log.error("INInteraction donate failed: \(error)") }
            }
            return intent
        }
    }

    /// MDI path is synchronous (no network). URL path downloads, caches, and downsamples the avatar.
    private func avatarImage(
        for source: NotificationSenderInfo.Source,
        api: HomeAssistantAPI
    ) -> Guarantee<INImage?> {
        switch source {
        case let .mdi(name, background, foreground):
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
            let cacheKey = notificationIconCacheKey(for: url)
            // The cache stores the ORIGINAL downloaded bytes, not the downsampled
            // bytes, so a future caller can re-downsample at a different size if
            // needed (e.g. notification content extension at higher resolution).
            if let cached = cache.data(forKey: cacheKey) {
                return .value(Self.image(fromOriginalData: cached))
            }
            return Guarantee { seal in
                api.DownloadDataAt(url: url, needsAuth: needsAuth).done { [cache] downloadedFile in
                    guard let data = try? Data(contentsOf: downloadedFile) else {
                        Current.Log.error("Failed to read downloaded avatar from \(downloadedFile.path) for url \(url)")
                        seal(nil); return
                    }
                    cache.setData(data, forKey: cacheKey)
                    seal(Self.image(fromOriginalData: data))
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
        case let .mdi(name, background, foreground):
            iconKey = "\(name)|\(background.hexDescription())|\(foreground.hexDescription())"
        case let .iconURL(url, _):
            iconKey = url.absoluteString
        }
        return "ha-sender:\(sender.senderName.lowercased()):\(iconKey)"
    }

    /// Reduce the source image to at most `maxDimension` px on the longer side, returning
    /// fresh PNG bytes suitable for `INImage(imageData:)`. Returns `nil` if the data
    /// isn't a decodable image — caller falls back to the raw data.
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
    private static func downsample(data: Data, maxDimension: CGFloat) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
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

    /// Wrap original-PNG-or-JPEG bytes in an `INImage`, downsampling first when possible.
    /// Falls back to handing the raw bytes to `INImage` if ImageIO can't decode them.
    private static func image(fromOriginalData data: Data) -> INImage {
        INImage(imageData: downsample(data: data, maxDimension: 256) ?? data)
    }
}

private extension UIColor {
    /// Stable hex serialization used only for conversation-ID construction.
    func hexDescription() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
