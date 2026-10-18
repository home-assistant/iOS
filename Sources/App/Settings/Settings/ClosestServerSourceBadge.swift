import SFSafeSymbols
import Shared
import SwiftUI

/// Says which signal picked the server the "Closest Server" row names: the Wi-Fi network this
/// device is on, or its distance to that server's Home zone.
///
/// A quiet capsule rather than a coloured one, like the sensor badges: the row states a fact and
/// this qualifies where the fact came from, so it sits beside the value it describes.
struct ClosestServerSourceBadge: View {
    let source: ServerProximitySource

    var body: some View {
        // A plain HStack, not a `Label`: inside a `List` the label style lays the icon and the
        // title out in separate columns sized for a full-width row, which leaves the capsule
        // holding the icon alone.
        HStack(spacing: DesignSystem.Spaces.half) {
            Image(systemSymbol: symbol)
            Text(title)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignSystem.Spaces.one)
        .padding(.vertical, DesignSystem.Spaces.micro)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        // Keeps its shape wherever it is placed, rather than being squeezed by a neighbour
        // that wants the width.
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var title: String {
        switch source {
        case .homeNetwork:
            return L10n.Settings.ServerSwitching.ClosestServer.Source.Network.title
        case .location:
            return L10n.Settings.ServerSwitching.ClosestServer.Source.Location.title
        }
    }

    private var symbol: SFSymbol {
        switch source {
        case .homeNetwork:
            return .wifi
        case .location:
            return .locationFill
        }
    }

    private var accessibilityLabel: String {
        switch source {
        case .homeNetwork:
            return L10n.Settings.ServerSwitching.ClosestServer.Source.Network.accessibilityLabel
        case .location:
            return L10n.Settings.ServerSwitching.ClosestServer.Source.Location.accessibilityLabel
        }
    }
}

#Preview {
    List {
        VStack(alignment: .trailing, spacing: DesignSystem.Spaces.half) {
            HStack {
                Text("Closest Server")
                Spacer()
                Text("Casa")
                    .foregroundStyle(.secondary)
            }
            ClosestServerSourceBadge(source: .homeNetwork)
        }
        VStack(alignment: .trailing, spacing: DesignSystem.Spaces.half) {
            HStack {
                Text("Closest Server")
                Spacer()
                Text("Casa · 1.2 km")
                    .foregroundStyle(.secondary)
            }
            ClosestServerSourceBadge(source: .location(distance: 1200))
        }
    }
}
