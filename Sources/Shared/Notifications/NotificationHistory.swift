import Foundation
import UserNotifications

public struct NotificationHistoryEntry: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable, CaseIterable {
        case local
        case remote
        case liveActivityLocal
        case liveActivityRemote
    }

    public var id: String
    public var date: Date
    public var kind: Kind
    public var title: String?
    public var subtitle: String?
    public var body: String?
    public var payloadJSON: String?

    public init(
        id: String = UUID().uuidString,
        date: Date = Current.date(),
        kind: Kind,
        title: String? = nil,
        subtitle: String? = nil,
        body: String? = nil,
        payloadJSON: String? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.payloadJSON = payloadJSON
    }

    public init(
        content: UNNotificationContent,
        kind: Kind,
        date: Date = Current.date()
    ) {
        self.init(
            date: date,
            kind: kind,
            title: content.title.isEmpty ? nil : content.title,
            subtitle: content.subtitle.isEmpty ? nil : content.subtitle,
            body: content.body.isEmpty ? Self.alertBody(from: content.userInfo) : content.body,
            payloadJSON: Self.payloadJSONString(from: content.userInfo)
        )
    }

    public var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }
        if let body, !body.isEmpty {
            return body
        }
        if let subtitle, !subtitle.isEmpty {
            return subtitle
        }
        return L10n.SettingsDetails.Notifications.History.noContent
    }

    private static func alertBody(from userInfo: [AnyHashable: Any]) -> String? {
        guard let aps = userInfo["aps"] as? [String: Any] else { return nil }
        if let message = aps["alert"] as? String {
            return message
        }
        if let alert = aps["alert"] as? [String: Any], let body = alert["body"] as? String {
            return body
        }
        return nil
    }

    private static let redactedKeys: Set<String> = ["hass_confirm_id", "webhook_id"]

    static func payloadJSONString(from userInfo: [AnyHashable: Any]) -> String? {
        guard let dictionary = jsonSafe(userInfo) as? [String: Any], !dictionary.isEmpty,
              JSONSerialization.isValidJSONObject(dictionary) else {
            return nil
        }

        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: options) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func jsonSafe(_ value: Any) -> Any? {
        if value is NSNull {
            return nil
        }
        if let number = value as? NSNumber {
            return number
        }
        if let string = value as? String {
            return string
        }
        if let array = value as? [Any] {
            return array.compactMap { jsonSafe($0) }
        }
        if let dictionary = value as? [AnyHashable: Any] {
            var output: [String: Any] = [:]
            for (key, nested) in dictionary {
                if let key = key as? String, !redactedKeys.contains(key), let safe = jsonSafe(nested) {
                    output[key] = safe
                }
            }
            return output
        }
        if JSONSerialization.isValidJSONObject([value]) {
            return value
        }
        return String(describing: value)
    }
}

public protocol NotificationHistoryStoreProtocol {
    func record(_ entry: NotificationHistoryEntry)
    func getEntries() -> [NotificationHistoryEntry]
    func clearAllEntries()
}

final class NotificationHistoryStore: NotificationHistoryStoreProtocol {
    static let entriesCacheLimit = 500

    private let queue = DispatchQueue(label: "io.home-assistant.notification-history-store")

    func record(_ entry: NotificationHistoryEntry) {
        queue.sync {
            coordinatedWrite { entries in
                var entries = entries
                entries.append(entry)
                if entries.count > Self.entriesCacheLimit {
                    entries = Array(entries.suffix(Self.entriesCacheLimit))
                }
                return entries
            }
        }
    }

    func getEntries() -> [NotificationHistoryEntry] {
        queue.sync { coordinatedRead() }
    }

    func clearAllEntries() {
        queue.sync { coordinatedWrite { _ in [] } }
    }

    private func coordinatedRead() -> [NotificationHistoryEntry] {
        var result: [NotificationHistoryEntry] = []
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(
            readingItemAt: AppConstants.notificationHistoryFile,
            options: .withoutChanges,
            error: &coordinationError
        ) { url in
            result = decodeEntries(at: url)
        }
        if let coordinationError {
            Current.Log.error("Failed to coordinate notification history read: \(coordinationError)")
        }
        return result
    }

    private func coordinatedWrite(_ transform: ([NotificationHistoryEntry]) -> [NotificationHistoryEntry]) {
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(
            writingItemAt: AppConstants.notificationHistoryFile,
            options: [],
            error: &coordinationError
        ) { url in
            let updated = transform(decodeEntries(at: url))
            do {
                let data = try JSONEncoder().encode(updated)
                try data.write(to: url, options: .atomic)
            } catch {
                Current.Log.error("Error saving notification history: \(error)")
            }
        }
        if let coordinationError {
            Current.Log.error("Failed to coordinate notification history write: \(coordinationError)")
        }
    }

    private func decodeEntries(at url: URL) -> [NotificationHistoryEntry] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = FileManager.default.contents(atPath: url.path) else {
            return []
        }
        do {
            return try JSONDecoder().decode([NotificationHistoryEntry].self, from: data)
        } catch {
            Current.Log.error("Failed to decode notification history cache, error: \(error)")
            return []
        }
    }
}

public extension NotificationHistoryEntry.Kind {
    var displayText: String {
        switch self {
        case .local:
            return L10n.SettingsDetails.Notifications.History.Kind.local
        case .remote:
            return L10n.SettingsDetails.Notifications.History.Kind.remote
        case .liveActivityLocal:
            return L10n.SettingsDetails.Notifications.History.Kind.liveActivityLocal
        case .liveActivityRemote:
            return L10n.SettingsDetails.Notifications.History.Kind.liveActivityRemote
        }
    }
}
