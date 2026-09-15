#if !os(watchOS)
import HAIconic
import SwiftUI

/// The control under a tile: a brightness slider, the buttons that open and close a cover, the ones
/// that lock and unlock a door.
///
/// Each is a design-system component already; what this adds is the entity's own value going in and
/// the service the frontend's feature calls coming out. The features that need a control this
/// package does not have yet — a thermostat's target, a fan's speed, an alarm's modes — draw
/// nothing rather than something that does not work.
public struct HomeTileFeatureView: View {
    @Environment(\.homeDashboard) private var context

    private let feature: HomeTileFeature?
    private let entityId: String

    public init(feature: HomeTileFeature?, entityId: String) {
        self.feature = feature
        self.entityId = entityId
    }

    public var body: some View {
        switch feature {
        case .lightBrightness:
            HomeBrightnessFeatureView(entityId: entityId)
        case .coverOpenClose:
            coverButtons
        case .lockCommands:
            lockButtons
        case .targetTemperature, .fanSpeed, .alarmModes, nil:
            EmptyView()
        }
    }

    private var coverButtons: some View {
        HAControlButtonGroup {
            HAControlButton(icon: .arrowUpIcon, label: context.strings.coverOpen) {
                context.perform(.performAction(HomeServiceCall(service: "cover.open_cover", entityId: entityId)))
            }
            HAControlButton(icon: .stopIcon, label: context.strings.coverStop) {
                context.perform(.performAction(HomeServiceCall(service: "cover.stop_cover", entityId: entityId)))
            }
            HAControlButton(icon: .arrowDownIcon, label: context.strings.coverClose) {
                context.perform(.performAction(HomeServiceCall(service: "cover.close_cover", entityId: entityId)))
            }
        }
    }

    private var lockButtons: some View {
        HAControlButtonGroup {
            HAControlButton(icon: .lockIcon, label: context.strings.lock) {
                context.perform(.performAction(HomeServiceCall(service: "lock.lock", entityId: entityId)))
            }
            HAControlButton(icon: .lockOpenIcon, label: context.strings.unlock) {
                context.perform(.performAction(HomeServiceCall(service: "lock.unlock", entityId: entityId)))
            }
        }
    }
}

#Preview {
    VStack {
        HomeTileCardView(config: HomeTileCardConfig(entityId: "light.kitchen_counter", feature: .lightBrightness))
        HomeTileCardView(config: HomeTileCardConfig(entityId: "cover.garage_door", feature: .coverOpenClose))
        HomeTileCardView(config: HomeTileCardConfig(entityId: "lock.front_door", feature: .lockCommands))
    }
    .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
    .padding()
    .background(Color.haSecondaryBackground)
}

#endif
