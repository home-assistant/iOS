#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import SwiftUI

/// ActivityAttributes for Home Assistant Live Activities.
///
/// Field names intentionally mirror the Android companion app's notification fields
/// so that automations can target both platforms with minimal differences.
///
/// ⚠️ NEVER rename this struct or its fields post-ship.
/// The `attributes-type` string in APNs push-to-start payloads must exactly match
/// the Swift struct name (case-sensitive). Renaming breaks all in-flight activities.
@available(iOS 17.2, *)
public struct HALiveActivityAttributes: ActivityAttributes {
    // MARK: - Static Attributes (set once at creation, cannot change)

    /// Unique identifier for this Live Activity. Maps to `tag` in the notification payload.
    /// Same semantics as Android's `tag`: the same tag value updates in-place.
    public let tag: String

    /// Display title for the activity. Maps to `title` in the notification payload.
    public let title: String

    public static var defaultTitle: String { L10n.LiveActivity.defaultTitle }

    /// Webhook id of the Home Assistant server that started this activity, so a tap can open
    /// the originating server when several are configured. Optional: nil for activities created
    /// before this shipped, or when the start path doesn't supply it.
    public let serverWebhookId: String?

    /// Server send-time of the push-to-start, in Unix epoch seconds, stamped by the push relay.
    /// When Core re-sends a start before it has a per-activity token, two activities can exist for
    /// one tag; the registry keeps the one with the largest `startedAt` and dismisses the rest, so
    /// duplicates collapse to the newest deterministically (ActivityKit exposes no creation order).
    /// Optional: nil for activities started before this shipped, which then sort oldest.
    public let startedAt: TimeInterval?

    /// Static-attribute coding keys. `serverWebhookId` maps to the snake_case `webhook_id` key
    /// carried in the APNs push-to-start `attributes`. Adding optional fields is safe; renaming
    /// or removing breaks in-flight activities.
    enum CodingKeys: String, CodingKey {
        case tag
        case title
        case serverWebhookId = "webhook_id"
        case startedAt = "started_at"
    }

    // MARK: - Dynamic State

    /// Codable state that can be updated via push or local update.
    /// Field names map to Android companion app notification data fields.
    public struct ContentState: Codable, Hashable {
        /// Dynamic display title. Mirrors top-level `title` so updates can refresh the header.
        public var title: String?

        /// Primary body text. Maps to `message` in the notification payload.
        public var message: String

        /// Short text for Dynamic Island compact trailing view.
        /// Maps to `critical_text` in the notification payload (≤ ~10 chars recommended).
        public var criticalText: String?

        /// Current progress value (raw integer). Maps to `progress`.
        public var progress: Int?

        /// Maximum progress value (raw integer). Maps to `progress_max`.
        public var progressMax: Int?

        /// If true, show a ticking timer instead of static text. Maps to `chronometer`.
        /// Counts down while `countdownEnd` is in the future; counts up from it once it
        /// has passed (so a `when` at or before now behaves as a count-up chronometer).
        public var chronometer: Bool?

        /// Absolute end date for the countdown timer.
        /// Computed from `when` + `when_relative` in the notification payload:
        ///   - `when_relative: true`  → `Date().addingTimeInterval(Double(when))`
        ///   - `when_relative: false` → `Date(timeIntervalSince1970: Double(when))`
        public var countdownEnd: Date?

        /// MDI icon slug for display. Maps to `notification_icon`.
        public var icon: String?

        /// Hex color string for icon accent. Maps to `notification_icon_color`.
        public var color: String?

        /// Path or URL opened when the activity is tapped, mirroring the `url` key from
        /// actionable notifications. Resolved like a notification tap: a relative HA path
        /// (e.g. `/lovelace/home`) opens in the frontend, an external URL opens in the
        /// browser. Nil just opens the originating server.
        public var url: String?

        /// Lock Screen background color, parsed like `notification_icon_color`. Defaults to black;
        /// text auto-contrasts with it. Maps to `background_color`.
        public var backgroundColor: String?

        /// Lock Screen text/foreground color, parsed like `notification_icon_color`.
        /// Overrides the auto-contrast default. Maps to `text_color`.
        public var textColor: String?

        /// Hex tint for the progress bar, parsed like `notification_icon_color`. Falls back to
        /// `notification_icon_color` when omitted. Maps to `progress_bar_color`.
        public var progressBarColor: String?

        // MARK: - Computed helpers (not sent over wire)

        /// Progress as a fraction in [0, 1] for use in SwiftUI ProgressView.
        public var progressFraction: Double? {
            guard let p = progress, let m = progressMax, m > 0 else { return nil }
            return Double(p) / Double(m)
        }

        // MARK: - CodingKeys

        /// Explicit coding keys so that JSON field names match the Android notification fields.
        enum CodingKeys: String, CodingKey {
            case title
            case message
            case criticalText = "critical_text"
            case progress
            case progressMax = "progress_max"
            case chronometer
            case countdownEnd = "countdown_end"
            case icon
            case color
            case url
            case backgroundColor = "background_color"
            case textColor = "text_color"
            case progressBarColor = "progress_bar_color"
        }

        // MARK: - Init

        public init(
            message: String,
            title: String? = nil,
            criticalText: String? = nil,
            progress: Int? = nil,
            progressMax: Int? = nil,
            chronometer: Bool? = nil,
            countdownEnd: Date? = nil,
            icon: String? = nil,
            color: String? = nil,
            url: String? = nil,
            backgroundColor: String? = nil,
            textColor: String? = nil,
            progressBarColor: String? = nil
        ) {
            self.title = title
            self.message = message
            self.criticalText = criticalText
            self.progress = progress
            self.progressMax = progressMax
            self.chronometer = chronometer
            self.countdownEnd = countdownEnd
            self.icon = icon
            self.color = color
            self.url = url
            self.backgroundColor = backgroundColor
            self.textColor = textColor
            self.progressBarColor = progressBarColor
        }

        // MARK: - Codable

        // ActivityKit decodes content-state with the default JSONDecoder, which
        // treats `Date` as seconds since 2001-01-01. HA core sends Unix epoch
        // seconds, so map countdownEnd manually via timeIntervalSince1970 to
        // avoid a ~31-year offset. The encoder is symmetric for round-tripping.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title), !decodedTitle.isEmpty {
                self.title = decodedTitle
            } else {
                self.title = nil
            }
            self.message = try container.decode(String.self, forKey: .message)
            self.criticalText = try container.decodeIfPresent(String.self, forKey: .criticalText)
            self.progress = try container.decodeIfPresent(Int.self, forKey: .progress)
            self.progressMax = try container.decodeIfPresent(Int.self, forKey: .progressMax)
            self.chronometer = try container.decodeIfPresent(Bool.self, forKey: .chronometer)
            if let timestamp = try container.decodeIfPresent(Double.self, forKey: .countdownEnd) {
                self.countdownEnd = Date(timeIntervalSince1970: timestamp)
            } else {
                self.countdownEnd = nil
            }
            self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
            self.color = try container.decodeIfPresent(String.self, forKey: .color)
            self.url = try container.decodeIfPresent(String.self, forKey: .url)
            self.backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
            self.textColor = try container.decodeIfPresent(String.self, forKey: .textColor)
            self.progressBarColor = try container.decodeIfPresent(String.self, forKey: .progressBarColor)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(message, forKey: .message)
            try container.encodeIfPresent(criticalText, forKey: .criticalText)
            try container.encodeIfPresent(progress, forKey: .progress)
            try container.encodeIfPresent(progressMax, forKey: .progressMax)
            try container.encodeIfPresent(chronometer, forKey: .chronometer)
            if let countdownEnd {
                try container.encode(countdownEnd.timeIntervalSince1970, forKey: .countdownEnd)
            }
            try container.encodeIfPresent(icon, forKey: .icon)
            try container.encodeIfPresent(color, forKey: .color)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
            try container.encodeIfPresent(textColor, forKey: .textColor)
            try container.encodeIfPresent(progressBarColor, forKey: .progressBarColor)
        }
    }

    // MARK: - Init

    public init(tag: String, title: String, serverWebhookId: String? = nil, startedAt: TimeInterval? = nil) {
        self.tag = tag
        self.title = title
        self.serverWebhookId = serverWebhookId
        self.startedAt = startedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tag = try container.decode(String.self, forKey: .tag)
        if let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title), !decodedTitle.isEmpty {
            self.title = decodedTitle
        } else {
            self.title = Self.defaultTitle
        }
        self.serverWebhookId = try container.decodeIfPresent(String.self, forKey: .serverWebhookId)
        self.startedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .startedAt)
    }
}
#endif
