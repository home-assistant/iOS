#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// Lock screen circular layout. A circular accessory only has room for one figure, so the widget
/// hands over the headline series — the grid flow when it has one, otherwise whichever series the
/// home does report.
@available(iOS 17, *)
public struct WidgetEnergyAccessoryCircularContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

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
                Text(verbatim: stat.icon.unicode)
                    .font(.custom(MaterialDesignIcons.familyName, size: 13))
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
            // The headline series' own icon, so an accessory with nothing to report still says what
            // it would have been reporting.
            Text(verbatim: MaterialDesignIcons.transmissionTowerIcon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: 20))
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
