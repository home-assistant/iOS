import Foundation

/// Turns one `media_player` entity's state into a `RemoteMediaSnapshot`.
///
/// The single mapping for both paths: the host app's HAKit subscription and the extension's
/// `render_template` reconciliation. Two independent mappings of the same attributes is how the
/// foreground and background views of a player drift apart, so the HAKit entry point is a thin
/// adapter over this rather than its own implementation.
///
/// This is also the one place a Home Assistant timestamp becomes the wire representation: an
/// ISO-8601 `media_position_updated_at` is parsed here and stored as Unix seconds, because the
/// snapshot crosses to Apple's infrastructure and back through a Home Assistant server.
public enum RemoteMediaSnapshotMapper {
    public static func map(
        entityId: String,
        state: String,
        attributes: [String: Any],
        serverId: String
    ) -> RemoteMediaEntityState? {
        guard entityId.hasPrefix("media_player.") else { return nil }
        let duration = finite(attributes["media_duration"]).flatMap { $0 > 0 ? $0 : nil }
        let position = finite(attributes["media_position"])
            .map { min(duration ?? .greatestFiniteMagnitude, max(0, $0)) }
        let timestamp = (attributes["media_position_updated_at"] as? String).flatMap(date(from:))
        let snapshot = RemoteMediaSnapshot(
            selection: .init(serverId: serverId, entityId: entityId),
            deviceName: attributes["friendly_name"] as? String ?? entityId,
            deviceClass: attributes["device_class"] as? String,
            state: state,
            title: nonEmpty(attributes["media_title"]),
            artist: nonEmpty(attributes["media_artist"]),
            album: nonEmpty(attributes["media_album_name"]),
            contentId: nonEmpty(attributes["media_content_id"]),
            duration: duration,
            position: position,
            positionUpdatedAtUnix: position == nil ? nil : timestamp?.timeIntervalSince1970,
            artwork: nil,
            volume: finite(attributes["volume_level"]).map { min(1, max(0, $0)) },
            isMuted: attributes["is_volume_muted"] as? Bool,
            features: .init(rawValue: max(0, intValue(attributes["supported_features"]) ?? 0))
        )
        return .init(snapshot: snapshot, artworkSource: nonEmpty(attributes["entity_picture"]))
    }

    /// Home Assistant timestamps carry fractional seconds, but not always, and a template renders
    /// them through `isoformat()` which uses a `+00:00` offset rather than `Z`.
    /// `ISO8601DateFormatter` rejects a string whose precision does not match its options, so each
    /// shape gets its own attempt.
    static func date(from text: String) -> Date? {
        for formatter in [fractionalSecondsFormatter, wholeSecondsFormatter] {
            if let date = formatter.date(from: text) { return date }
        }
        // `datetime.isoformat()` with a space separator, which templates can also produce.
        return spaceSeparatedFormatter.date(from: text)
    }

    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let spaceSeparatedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"
        return formatter
    }()

    private static func finite(_ value: Any?) -> Double? {
        let candidate: Double?
        switch value {
        case let number as NSNumber: candidate = number.doubleValue
        case let text as String: candidate = Double(text)
        default: candidate = nil
        }
        guard let candidate, candidate.isFinite else { return nil }
        return candidate
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let text as String: return Int(text)
        default: return nil
        }
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
}
