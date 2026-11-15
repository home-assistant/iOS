#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// An event-style action from the notification payload.
public struct HALiveActivityAction: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String?

    enum CodingKeys: String, CodingKey {
        case id = "action"
        case title
        case icon
    }

    public init(id: String, title: String, icon: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
    }

    public var systemImage: String? {
        guard let icon, icon.hasPrefix("sfsymbols:"), icon.utf8.count <= 96 else { return nil }
        let name = String(icon.dropFirst("sfsymbols:".count))
        return name.isEmpty ? nil : name
    }

    static func visibleActions(_ actions: [Self]) -> [Self] {
        var identifiers = Set<String>()
        return Array(actions.filter { action in
            !action.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && action.id.utf8.count <= 64 &&
                action.id != "URI" && action.id != "REPLY" &&
                !action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && action.title.utf8
                .count <= 96 &&
                identifiers.insert(action.id).inserted
        }.prefix(3))
    }

    static func notificationActions(_ value: Any?) -> [Self] {
        guard let entries = value as? [Any] else { return [] }
        return entries.compactMap { entry in
            guard let entry = entry as? [String: Any],
                  let id = entry["action"] as? String,
                  let title = entry["title"] as? String,
                  entry["uri"] == nil,
                  (entry["behavior"] as? String)?.lowercased() != "textinput" else { return nil }
            let icon = (entry["icon"] as? String).flatMap { $0.utf8.count <= 96 ? $0 : nil }
            return Self(id: id, title: title, icon: icon)
        }
    }
}
#endif
