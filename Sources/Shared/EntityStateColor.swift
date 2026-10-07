import Foundation
import HADesignSystem
import SwiftUI

/// Port of `common/entity/state_color.ts` (and `common/entity/color/battery_color.ts`) in
/// home-assistant/frontend: the `--state-…` custom property an entity's icon is painted with.
///
/// The frontend builds a `var()` fallback chain from most to least specific and lets CSS pick the
/// first property that is actually defined. ``FrontendColors`` is generated from the same
/// `color.globals.ts`, so "is defined" here is simply "has a case", and the chain resolves the same
/// way — including the device-class defaults (`--state-binary_sensor-gas-on-color`, …).
public enum EntityStateColor {
    /// `STATE_COLORED_DOMAIN`: the domains that take a state color at all. Anything else keeps the
    /// neutral icon color.
    public static let stateColoredDomains: Set<String> = [
        "alarm_control_panel",
        "alert",
        "automation",
        "binary_sensor",
        "calendar",
        "camera",
        "climate",
        "cover",
        "device_tracker",
        "fan",
        "group",
        "humidifier",
        "input_boolean",
        "lawn_mower",
        "light",
        "lock",
        "media_player",
        "person",
        "plant",
        "remote",
        "schedule",
        "script",
        "siren",
        "sun",
        "switch",
        "timer",
        "update",
        "vacuum",
        "valve",
        "water_heater",
        "weather",
    ]

    /// The custom property names the frontend would try, most specific first.
    public static func properties(
        domain: String,
        deviceClass: String?,
        state: String,
        active: Bool
    ) -> [String] {
        var properties: [String] = []
        let stateKey = slugify(state)
        let activeKey = active ? "active" : "inactive"

        if let deviceClass, !deviceClass.isEmpty {
            properties.append("--state-\(domain)-\(deviceClass)-\(stateKey)-color")
        }

        properties.append(contentsOf: [
            "--state-\(domain)-\(stateKey)-color",
            "--state-\(domain)-\(activeKey)-color",
            "--state-\(activeKey)-color",
        ])

        return properties
    }

    /// The color the frontend gives this entity, or `nil` when its domain isn't state-colored — the
    /// caller then falls back to the neutral defaults the tile card's CSS provides.
    ///
    /// - Parameters:
    ///   - domain: the entity's own domain, lowercased.
    ///   - deviceClass: the raw `device_class` attribute, if any.
    ///   - state: the raw entity state, lowercased.
    ///   - groupMemberDomain: for a `group`, the single domain all its members share, whose palette
    ///     the group borrows.
    public static func color(
        domain: String,
        deviceClass: String?,
        state: String,
        groupMemberDomain: String? = nil
    ) -> Color? {
        if state == EntityStateActive.unavailable {
            return FrontendColors.stateUnavailableColor.color
        }

        let active = EntityStateActive.isActive(domain: domain, state: state)

        // Battery sensors are colored by level rather than by state.
        if domain == "sensor", deviceClass == "battery", let property = batteryColorProperty(for: state) {
            return property.color
        }

        // A group whose members all share one domain borrows that domain's palette, while staying
        // active/inactive by the group's own rules.
        if domain == "group", let groupMemberDomain, stateColoredDomains.contains(groupMemberDomain) {
            return resolve(propertyDomain: groupMemberDomain, deviceClass: deviceClass, state: state, active: active)
        }

        guard stateColoredDomains.contains(domain) else { return nil }
        return resolve(propertyDomain: domain, deviceClass: deviceClass, state: state, active: active)
    }

    /// `batteryStateColorProperty`: a battery sensor is green/orange/red by percentage, and keeps
    /// the ordinary state handling when its state isn't a number.
    public static func batteryColorProperty(for state: String) -> FrontendColors? {
        guard let value = Double(state) else { return nil }
        if value >= 70 { return .stateSensorBatteryHighColor }
        if value >= 30 { return .stateSensorBatteryMediumColor }
        return .stateSensorBatteryLowColor
    }

    private static func resolve(
        propertyDomain: String,
        deviceClass: String?,
        state: String,
        active: Bool
    ) -> Color? {
        for name in properties(domain: propertyDomain, deviceClass: deviceClass, state: state, active: active) {
            if let variable = FrontendColors(rawValue: name) {
                return variable.color
            }
        }
        return nil
    }

    /// The frontend slugifies the state before building the property name (`slugify(state, "_")`).
    /// States come from the backend as ASCII slugs already, so the transliteration table `slugify`
    /// carries for user-entered names has nothing to do here.
    static func slugify(_ value: String) -> String {
        var slug = ""
        var lastWasDelimiter = false
        for character in value.lowercased() {
            if character.isASCII, character.isLetter || character.isNumber {
                slug.append(character)
                lastWasDelimiter = false
            } else if !lastWasDelimiter {
                slug.append("_")
                lastWasDelimiter = true
            }
        }
        while slug.hasPrefix("_") {
            slug.removeFirst()
        }
        while slug.hasSuffix("_") {
            slug.removeLast()
        }
        return slug.isEmpty ? "unknown" : slug
    }
}
