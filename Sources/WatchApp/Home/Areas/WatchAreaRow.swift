import SFSafeSymbols
import Shared
import SwiftUI

/// A single area on the home screen or the per-server area list; tapping pushes the area's
/// entities through the home stack's `watchNavigate` action. Renders as an icon-only tile in
/// the grid layout, matching `WatchFolderRow`.
struct WatchAreaRow: View {
    let area: AppArea
    var layout: WatchLayout = .list
    @Environment(\.watchNavigate) private var navigate

    var body: some View {
        Button {
            navigate(.areaEntities(areaId: area.areaId, serverId: area.serverId))
        } label: {
            label
        }
        .modify { view in
            if layout == .grid {
                view.watchHomeItemGridStyle(tint: nil)
            } else {
                view
                    .frame(maxWidth: .infinity)
                    .watchHomeItemRowStyle(tint: nil)
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if layout == .grid {
            Image(uiImage: icon.image(
                ofSize: .init(width: 28, height: 28),
                color: .white
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(area.name))
        } else {
            WatchHomeItemLabel(
                name: area.name,
                textColor: .white,
                icon: {
                    VStack {
                        Image(uiImage: icon.image(
                            ofSize: .init(width: 24, height: 24),
                            color: .white
                        ))
                        .padding()
                    }
                    .watchRowIconContainer(color: .white)
                },
                accessory: {
                    Image(systemSymbol: .chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            )
        }
    }

    private var icon: MaterialDesignIcons {
        if let iconName = area.icon {
            // The frontend's default icon for areas without a custom one.
            return MaterialDesignIcons(serversideValueNamed: iconName, fallback: .textureBoxIcon)
        }
        return .textureBoxIcon
    }
}

#Preview {
    MaterialDesignIcons.register()
    return List {
        WatchAreaRow(area: .init(
            id: "1-living_room",
            serverId: "1",
            areaId: "living_room",
            name: "Living Room",
            aliases: [],
            picture: nil,
            icon: "mdi:sofa",
            sortOrder: nil,
            entities: ["light.living_room"]
        ))
        WatchAreaRow(area: .init(
            id: "1-kitchen",
            serverId: "1",
            areaId: "kitchen",
            name: "Kitchen",
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: ["light.kitchen"]
        ))
    }
}
