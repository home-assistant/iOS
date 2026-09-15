import Foundation

/// What counts as a device that belongs to no room. The port of the frontend's
/// `OTHER_DEVICES_FILTERS`: everything with no area, minus the platforms and domains that are not
/// devices at all — automations, scripts, the app's own entities, the voice pipeline's.
public enum HomeOtherDevicesFilters {
    /// The voice entities, which are part of Assist rather than of the home.
    private static let assistDomains = ["assist_satellite", "conversation", "stt", "tts"]

    public static let filters: [HomeEntityFilter] = [
        HomeEntityFilter(
            hiddenDomains: [
                "ai_task",
                "automation",
                "configurator",
                "device_tracker",
                "event",
                "geo_location",
                "notify",
                "persistent_notification",
                "script",
                "sun",
                "tag",
                "todo",
                "zone",
            ] + assistDomains,
            areas: [nil],
            hiddenPlatforms: [
                "automation",
                "script",
                "hassio",
                "backup",
                "mobile_app",
                "zone",
                "person",
            ]
        ),
    ]
}
