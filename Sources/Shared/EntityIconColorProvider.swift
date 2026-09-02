import Foundation
import HADesignSystem
import SwiftUI

/// The color an entity's icon is drawn with, following home-assistant/frontend's tile card
/// (`hui-tile-card`'s `_computeStateColor` plus the neutral defaults its stylesheet sets):
///
/// 1. a light's own color, when it reports one;
/// 2. the `--state-…` palette for the entity's domain, device class and state — see
///    ``EntityStateColor``;
/// 3. `--state-icon-color` when active and `--state-inactive-color` when not, for the domains that
///    take no state color at all (sensors, numbers, scripts, …).
public enum EntityIconColorProvider {
    /// The color for an entity whose live color (if any) has already been resolved.
    ///
    /// - Parameters:
    ///   - domain: the entity's own domain, lowercased.
    ///   - deviceClass: the raw `device_class` attribute, if any.
    ///   - state: the raw entity state; case is normalized here.
    ///   - liveColor: the light's own color, from ``liveColor(domain:rgbColor:hsColor:)``.
    ///   - groupMemberDomain: for a `group`, the single domain all its members share.
    ///   - customColor: a color the user picked for this entity on this surface, which takes
    ///     precedence over everything below it.
    public static func iconColor(
        domain: String,
        deviceClass: String? = nil,
        state: String,
        liveColor: Color? = nil,
        groupMemberDomain: String? = nil,
        customColor: Color? = nil
    ) -> Color {
        let normalizedState = state.lowercased()
        let active = EntityStateActive.isActive(domain: domain, state: normalizedState)

        // The tile card's `color` option: a picked color only applies while the entity is active,
        // so an off light still reads as off.
        if let customColor {
            return active ? customColor : neutralColor(active: false)
        }

        // A light that is on shows its own color rather than the domain accent.
        if active, let liveColor {
            return liveColor
        }

        if let stateColor = EntityStateColor.color(
            domain: domain,
            deviceClass: deviceClass,
            state: normalizedState,
            groupMemberDomain: groupMemberDomain
        ) {
            return stateColor
        }

        return neutralColor(active: active)
    }

    /// The same, reading the device class, the light's color and a group's shared domain straight
    /// out of the entity's attributes.
    public static func iconColor(
        domain: String,
        state: String,
        attributes: [String: Any]?,
        customColor: Color? = nil
    ) -> Color {
        let colorAttributes = EntityColorAttributesParser.parse(from: attributes)
        return iconColor(
            domain: domain,
            deviceClass: attributes?["device_class"] as? String,
            state: state,
            liveColor: liveColor(
                domain: domain,
                rgbColor: colorAttributes.rgbColor,
                hsColor: colorAttributes.hsColor
            ),
            groupMemberDomain: domain == Domain.group.rawValue ? groupMemberDomain(attributes: attributes) : nil,
            customColor: customColor
        )
    }

    /// `computeGroupDomain`: the domain every member of a group shares, when they all share one.
    public static func groupMemberDomain(attributes: [String: Any]?) -> String? {
        guard let entityIds = attributes?["entity_id"] as? [String] else { return nil }
        let domains = Set(entityIds.compactMap { $0.split(separator: ".").first.map(String.init) })
        return domains.count == 1 ? domains.first : nil
    }

    /// What the tile card falls back to when a domain has no state color of its own:
    /// `--state-icon-color` while active, `--state-inactive-color` otherwise.
    public static func neutralColor(active: Bool) -> Color {
        active ? FrontendColors.stateIconColor.color : FrontendColors.stateInactiveColor.color
    }

    /// A light's own color, contrast-adjusted the way the tile card does before painting with it:
    /// nearly unsaturated colors are pushed to 40% saturation, and a white light is dimmed instead,
    /// so a "white" bulb doesn't render as an invisible icon.
    ///
    /// `nil` for every other domain, and for a light that reports no color at all.
    public static func liveColor(
        domain: String,
        rgbColor: [Int]?,
        hsColor: [Double]?
    ) -> Color? {
        guard domain == Domain.light.rawValue else { return nil }
        guard let rgb = rgbComponents(rgbColor: rgbColor, hsColor: hsColor) else {
            return nil
        }

        let adjusted = contrastAdjusted(rgb)
        return Color(
            .sRGB,
            red: adjusted[0] / 255,
            green: adjusted[1] / 255,
            blue: adjusted[2] / 255
        )
    }

    private static func rgbComponents(rgbColor: [Int]?, hsColor: [Double]?) -> [Double]? {
        // `rgb_color` is the only attribute the frontend reads, and Home Assistant fills it in for
        // every color mode. `hs_color` is a fallback for the rare light that reports hue and
        // saturation without the RGB approximation.
        if let rgbColor, rgbColor.count == 3 {
            return rgbColor.map(Double.init)
        }
        if let hsColor, hsColor.count == 2 {
            return hsv2rgb([hsColor[0], hsColor[1] / 100, 255])
        }
        return nil
    }

    private static func contrastAdjusted(_ rgb: [Double]) -> [Double] {
        var hsv = rgb2hsv(rgb)
        if hsv[1] < 0.4 {
            if hsv[1] < 0.1 {
                // Special case for a very light color (e.g. white): darken it instead.
                hsv[2] = 225
            } else {
                hsv[1] = 0.4
            }
        }
        return hsv2rgb(hsv)
    }

    /// `rgb2hsv` from `common/color/convert-color.ts`: hue in degrees, saturation 0-1, value 0-255.
    static func rgb2hsv(_ rgb: [Double]) -> [Double] {
        let (red, green, blue) = (rgb[0], rgb[1], rgb[2])
        let value = max(red, green, blue)
        let chroma = value - min(red, green, blue)

        var hue: Double = 0
        if chroma != 0 {
            if value == red {
                hue = (green - blue) / chroma
            } else if value == green {
                hue = 2 + (blue - red) / chroma
            } else {
                hue = 4 + (red - green) / chroma
            }
        }

        return [60 * (hue < 0 ? hue + 6 : hue), value == 0 ? 0 : chroma / value, value]
    }

    /// `hsv2rgb` from `common/color/convert-color.ts`.
    static func hsv2rgb(_ hsv: [Double]) -> [Double] {
        let (hue, saturation, value) = (hsv[0], hsv[1], hsv[2])
        func component(_ n: Double) -> Double {
            let k = (n + hue / 60).truncatingRemainder(dividingBy: 6)
            return value - value * saturation * max(min(k, 4 - k, 1), 0)
        }
        return [component(5), component(3), component(1)]
    }
}
