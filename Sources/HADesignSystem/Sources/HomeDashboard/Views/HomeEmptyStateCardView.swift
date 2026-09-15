#if !os(watchOS)
import HAIconic
import SwiftUI

/// What a view shows when the strategy found nothing to put in it, and what the user can do about it.
public struct HomeEmptyStateCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeEmptyStateCardConfig

    public init(config: HomeEmptyStateCardConfig) {
        self.config = config
    }

    public var body: some View {
        HAEmptyStateView(
            icon: HomeDashboardIconName.icon(config.icon),
            heading: config.title,
            description: config.content
        ) {
            VStack(spacing: DesignSystem.Spaces.one) {
                ForEach(config.buttons) { button in
                    HomeEmptyStateButton(config: button)
                }
            }
        }
    }
}

/// One button under an empty state. The prominent one is the thing to do here; the rest are ways
/// round it.
private struct HomeEmptyStateButton: View {
    @Environment(\.homeDashboard) private var context

    let config: HomeEmptyStateButtonConfig

    var body: some View {
        Button {
            context.perform(config.action)
        } label: {
            Label {
                Text(config.text)
            } icon: {
                MaterialDesignIconsImage(icon: HomeDashboardIconName.icon(config.icon), size: 18)
            }
        }
        .modifier(HomeEmptyStateButtonStyle(isProminent: config.isProminent))
    }
}

/// `buttonStyle` returns a different type per style, so the choice cannot sit in a `ViewBuilder`
/// branch without erasing it — a modifier keeps both branches one type.
private struct HomeEmptyStateButtonStyle: ViewModifier {
    let isProminent: Bool

    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

#Preview {
    HomeEmptyStateCardView(config: HomeEmptyStateCardConfig(
        icon: "mdi:home-assistant",
        title: "No devices here yet",
        content: "Add lights, switches, sensors, or other smart home devices to get started.",
        buttons: [
            HomeEmptyStateButtonConfig(
                id: "add",
                icon: "mdi:plus",
                text: "Add new device",
                isProminent: true,
                action: .navigate("/config")
            ),
            HomeEmptyStateButtonConfig(
                id: "areas",
                icon: "mdi:home-edit",
                text: "Edit areas",
                action: .navigate("/config/areas/dashboard")
            ),
        ]
    ))
    .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
    .background(Color.haSecondaryBackground)
}
#endif
