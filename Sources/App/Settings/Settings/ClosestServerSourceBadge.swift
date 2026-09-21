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
        Label {
            Text(title)
        } icon: {
            Image(systemSymbol: symbol)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignSystem.Spaces.one)
        .padding(.vertical, DesignSystem.Spaces.micro)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        // Keeps its shape next to a server name and distance that want the width.
        .fixedSize()
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
        HStack {
            Text("Closest Server")
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spaces.half) {
                Text("Casa")
                    .foregroundStyle(.secondary)
                ClosestServerSourceBadge(source: .homeNetwork)
            }
        }
        HStack {
            Text("Closest Server")
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spaces.half) {
                Text("Casa · 1.2 km")
                    .foregroundStyle(.secondary)
                ClosestServerSourceBadge(source: .location(distance: 1200))
            }
        }
    }
}
