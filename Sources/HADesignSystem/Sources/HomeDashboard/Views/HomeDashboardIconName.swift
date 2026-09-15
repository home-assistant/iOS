#if !os(watchOS)
import HAIconic
import SwiftUI

/// Server-side icon names — `"mdi:home-floor-1"` — turned into the drawable the design system uses.
/// The prefixes and the renames are the frontend's own, via ``MDIMigration``.
public enum HomeDashboardIconName {
    /// The prefixes Home Assistant answers with a Material Design icon, its `MDI_PREFIXES`.
    private static let prefixes = ["mdi:", "hass:", "hassio:", "hademo:"]

    public static func icon(_ name: String?, fallback: MaterialDesignIcons = .dotsGridIcon) -> MaterialDesignIcons {
        guard let name, !name.isEmpty else {
            return fallback
        }
        let unprefixed = prefixes.first(where: name.hasPrefix).map { String(name.dropFirst($0.count)) } ?? name
        let normalized = unprefixed
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return MaterialDesignIcons(named: MDIMigration.migrate(icon: normalized), fallback: fallback)
    }
}
#endif
