import Foundation

/// Mirrors Home Assistant's `EntityCategory`, which decides where an entity belongs on its device
/// page and in everything generated from it.
///
/// An uncategorised entity is part of what the device is *for*: it shows in the device's main
/// entity list, lands on auto-generated dashboards and is exposed to Assist by default. A
/// categorised one is secondary — collapsed into its own section, left out of those defaults, and
/// still perfectly usable in automations and templates.
///
/// Sent at registration only: `register_sensor` is the one call Home Assistant reads it from, and
/// `update_sensor_states` carries state and nothing else.
public enum SensorEntityCategory: String, CaseIterable, Sendable {
    /// Changes the configuration of a device. No sensor the app reports is one — a sensor only
    /// ever reports — but it is half of Home Assistant's model and the field is general.
    case config
    /// Describes the device or the app rather than the world around it: its battery, its storage,
    /// the network it is on, the version it is running.
    case diagnostic
}
