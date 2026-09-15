#if !os(watchOS)
import HAIconic
import SwiftUI

/// A room on the overview: its icon, its name, and the readings the strategy asked for underneath.
/// The compact form of the frontend's `hui-area-card`, which is the only form the home strategy asks
/// for — a third of a row wide and two rows tall, three rooms to a line.
public struct HomeAreaCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeAreaCardConfig

    public init(config: HomeAreaCardConfig) {
        self.config = config
    }

    public var body: some View {
        HACard {
            VStack(spacing: DesignSystem.Spaces.one) {
                HATileIcon(icon: HomeDashboardIconName.icon(config.icon, fallback: .sofaIcon), color: .haPrimary)
                VStack(spacing: DesignSystem.Spaces.micro) {
                    Text(config.name)
                        .font(DesignSystem.Font.footnote)
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if let sensors {
                        Text(sensors)
                            .font(DesignSystem.Font.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(DesignSystem.Spaces.oneAndMicro)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { context.perform(config.tapAction) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(config.name))
            .accessibilityAddTraits(.isButton)
        }
        .modifier(HomeAreaZoomSource(areaId: config.areaId, namespace: context.zoomNamespace))
    }

    /// The readings across the foot — the area's temperature, when it has one.
    private var sensors: String? {
        let area = context.registry.area(config.areaId)
        let readings = config.sensorClasses.compactMap { sensorClass -> String? in
            switch sensorClass {
            case "temperature":
                return area?.temperatureEntityId.flatMap { context.presentation(of: $0)?.secondary }
            case "humidity":
                return area?.humidityEntityId.flatMap { context.presentation(of: $0)?.secondary }
            default:
                return nil
            }
        }
        return readings.isEmpty ? nil : readings.joined(separator: " · ")
    }
}

#Preview {
    HomeDashboardGrid {
        ForEach(HomeDashboardSampleHome.areas) { area in
            HomeAreaCardView(config: HomeAreaCardConfig(
                areaId: area.id,
                name: area.name,
                icon: area.icon,
                sensorClasses: area.temperatureEntityId == nil ? [] : ["temperature"],
                tapAction: .navigate(HomeDashboardPath.area(area.id))
            ))
            .homeDashboardColumns(4)
        }
    }
    .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
    .padding()
    .background(Color.haSecondaryBackground)
}
#endif
