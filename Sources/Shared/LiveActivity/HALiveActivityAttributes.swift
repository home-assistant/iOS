#if canImport(ActivityKit)
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
@available(iOS 16.1, *)
public struct HALiveActivityAttributes: ActivityAttributes {
    // MARK: - Static Attributes (set once at creation, cannot change)

    /// Unique identifier for this Live Activity. Maps to `tag` in the notification payload.
    /// Same semantics as Android's `tag`: the same tag value updates in-place.
    public let tag: String

    /// Display title for the activity. Maps to `title` in the notification payload.
    public let title: String

    // MARK: - Dynamic State

    /// Codable state that can be updated via push or local update.
    /// Field names map to Android companion app notification data fields.
    public struct ContentState: Codable, Hashable {
        /// Primary body text. Maps to `message` in the notification payload.
        public var message: String

        /// Short text for Dynamic Island compact trailing view.
        /// Maps to `critical_text` in the notification payload (≤ ~10 chars recommended).
        public var criticalText: String?

        /// Current progress value (raw integer). Maps to `progress`.
        public var progress: Int?

        /// Maximum progress value (raw integer). Maps to `progress_max`.
        public var progressMax: Int?

        /// If true, show a countdown timer instead of static text. Maps to `chronometer`.
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

        // MARK: - Computed helpers (not sent over wire)

        /// Progress as a fraction in [0, 1] for use in SwiftUI ProgressView.
        public var progressFraction: Double? {
            guard let p = progress, let m = progressMax, m > 0 else { return nil }
            return Double(p) / Double(m)
        }

        // MARK: - CodingKeys

        /// Explicit coding keys so that JSON field names match the Android notification fields.
        enum CodingKeys: String, CodingKey {
            case message
            case criticalText = "critical_text"
            case progress
            case progressMax = "progress_max"
            case chronometer
            case countdownEnd = "countdown_end"
            case icon
            case color
        }

        // MARK: - Init

        public init(
            message: String,
            criticalText: String? = nil,
            progress: Int? = nil,
            progressMax: Int? = nil,
            chronometer: Bool? = nil,
            countdownEnd: Date? = nil,
            icon: String? = nil,
            color: String? = nil
        ) {
            self.message = message
            self.criticalText = criticalText
            self.progress = progress
            self.progressMax = progressMax
            self.chronometer = chronometer
            self.countdownEnd = countdownEnd
            self.icon = icon
            self.color = color
        }
    }

    // MARK: - Init

    public init(tag: String, title: String) {
        self.tag = tag
        self.title = title
    }
}
#endif
