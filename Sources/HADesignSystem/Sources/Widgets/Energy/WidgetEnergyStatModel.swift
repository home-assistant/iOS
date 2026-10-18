#if !os(watchOS)
import Foundation
import HAIconic
import SFSafeSymbols
import SwiftUI

/// A single energy figure, already resolved into the words and colours it is drawn with.
///
/// Which series the figure belongs to, and whether it came from live power or a period total, is
/// settled before it gets here — the widget owns that; this is what ends up on screen.
public struct WidgetEnergyStatModel: Identifiable {
    public let id: String
    public let icon: MaterialDesignIcons
    public let value: String
    public let unit: String?
    public let label: String
    public let direction: WidgetEnergyDirection
    public let color: Color
    /// SF Symbol stand-in for `icon`, used by the inline accessory where the system renders a
    /// single symbol next to the text and the Material Design font is unavailable.
    public let accessorySymbol: SFSymbol

    public init(
        id: String,
        icon: MaterialDesignIcons,
        value: String,
        unit: String?,
        label: String,
        direction: WidgetEnergyDirection,
        color: Color,
        accessorySymbol: SFSymbol
    ) {
        self.id = id
        self.icon = icon
        self.value = value
        self.unit = unit
        self.label = label
        self.direction = direction
        self.color = color
        self.accessorySymbol = accessorySymbol
    }

    /// Value and unit on one line, e.g. "12,4 kWh", for the accessory layouts that can't stack them.
    public var valueWithUnit: String {
        guard let unit else { return value }
        return "\(value) \(unit)"
    }
}
#endif
