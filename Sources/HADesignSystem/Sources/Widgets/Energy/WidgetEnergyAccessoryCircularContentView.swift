#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// Lock screen circular layout. A circular accessory only has room for one figure, so the widget
/// hands over the headline series — solar when it has one, otherwise the grid flow.
@available(iOS 17, *)
public struct WidgetEnergyAccessoryCircularContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Glyphs are drawn as images here: see ``WidgetAccessoryIconView`` for why the lock screen
    /// cannot draw them as text in the icon font.
    private static let iconSize: CGFloat = 13
    private static let emptyIconSize: CGFloat = 20

    private let stat: WidgetEnergyStatModel?

    public init(stat: WidgetEnergyStatModel?) {
        self.stat = stat
    }

    public var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            content
        }
        .widgetBackground(Color.clear)
    }

    @ViewBuilder
    private var content: some View {
        if let stat {
            VStack(spacing: 0) {
                WidgetAccessoryIconView(icon: stat.icon, size: Self.iconSize)
                Text(verbatim: stat.value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                if let unit = stat.unit {
                    Text(verbatim: unit)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(DesignSystem.Spaces.half)
            .foregroundStyle(WidgetEnergyPalette.accessoryColor(stat.color, mode: renderingMode))
        } else {
            WidgetAccessoryIconView(icon: .solarPowerIcon, size: Self.emptyIconSize)
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyAccessoryCircularContentView(stat: WidgetEnergySampleData.stats.first)
        .frame(width: 76, height: 76)
}
#endif
