import SFSafeSymbols
import Shared
import SwiftUI

/// A single area on the home screen or the per-server area list; tapping pushes the area's
/// entities through the home stack's `watchNavigate` action.
struct WatchAreaRow: View {
    let area: AppArea
    @Environment(\.watchNavigate) private var navigate

    var body: some View {
        Button {
            navigate(.areaEntities(areaId: area.areaId, serverId: area.serverId))
        } label: {
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
        .frame(maxWidth: .infinity)
        .watchHomeItemRowStyle(tint: nil)
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
