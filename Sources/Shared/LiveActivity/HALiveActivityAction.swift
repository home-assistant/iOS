#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreFoundation
import Foundation

/// An event-style action from the notification payload.
public struct HALiveActivityAction: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String?
    public let showTitle: Bool?
    public let authenticationRequired: Bool

    enum CodingKeys: String, CodingKey {
        case id = "action"
        case title
        case icon
        case showTitle = "show_title"
        case authenticationRequired = "authentication_required"
        case uri
        case behavior
    }

    public init(
        id: String,
        title: String,
        icon: String? = nil,
        showTitle: Bool? = nil,
        authenticationRequired: Bool = true
    ) {
        self.id = id
        self.title = title
        self.icon = icon.flatMap { $0.utf8.count <= 96 ? $0 : nil }
        self.showTitle = showTitle
        self.authenticationRequired = authenticationRequired
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let behavior = try? container.decode(String.self, forKey: .behavior)
        guard !container.contains(.uri), behavior?.lowercased() != "textinput" else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Live Activity buttons support event actions only"
            )
        }
        try self.init(
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            icon: try? container.decode(String.self, forKey: .icon),
            showTitle: try? container.decode(Bool.self, forKey: .showTitle),
            authenticationRequired: (try? container.decode(Bool.self, forKey: .authenticationRequired)) ?? true
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(showTitle, forKey: .showTitle)
        if !authenticationRequired {
            try container.encode(false, forKey: .authenticationRequired)
        }
    }

    public var systemImage: String? {
        guard let icon, icon.hasPrefix("sfsymbols:") else { return nil }
        let name = String(icon.dropFirst("sfsymbols:".count))
        return name.isEmpty ? nil : name
    }

    static func visibleActions(_ actions: [Self]) -> [Self] {
        var identifiers = Set<String>()
        var visible: [Self] = []
        for action in actions {
            guard !action.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  action.id.utf8.count <= 64,
                  action.id != "URI", action.id != "REPLY",
                  !action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  action.title.utf8.count <= 96,
                  identifiers.insert(action.id).inserted else { continue }
            visible.append(action)
            if visible.count == 3 { break }
        }
        return visible
    }

    static func decodeActions(from list: inout UnkeyedDecodingContainer) -> [Self] {
        var actions: [Self] = []
        while !list.isAtEnd, let decoder = try? list.superDecoder() {
            if let action = try? Self(from: decoder) {
                actions.append(action)
            }
        }
        return visibleActions(actions)
    }

    static func notificationActions(_ value: Any?) -> [Self] {
        guard let entries = value as? [Any] else { return [] }
        return entries.compactMap { entry in
            guard let entry = entry as? [String: Any],
                  let id = entry["action"] as? String,
                  let title = entry["title"] as? String,
                  entry["uri"] == nil,
                  (entry["behavior"] as? String)?.lowercased() != "textinput" else { return nil }
            return Self(
                id: id,
                title: title,
                icon: entry["icon"] as? String,
                showTitle: notificationBoolean(entry["show_title"]),
                authenticationRequired: notificationBoolean(entry["authentication_required"]) ?? true
            )
        }
    }

    private static func notificationBoolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}
#endif
