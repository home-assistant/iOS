import SFSafeSymbols
import Shared
import SwiftUI

/// The header of a device section on the area and device screens: the device name, tappable to open
/// that device's own controls and sensors. Used by both the controls and the sensors sections.
struct WatchAreaDeviceSectionHeader: View {
    let group: WatchGroupedEntities.DeviceGroup
    let serverId: String
    /// Off on a device screen, where every section already sits under the parent the line names.
    var showsParentName: Bool = true
    @Environment(\.watchNavigate) private var navigate

    var body: some View {
        Button {
            navigate(.deviceEntities(deviceId: group.deviceId, serverId: serverId, name: group.name))
        } label: {
            HStack(spacing: DesignSystem.Spaces.half) {
                VStack(alignment: .leading, spacing: .zero) {
                    Text(verbatim: group.name)
                    if showsParentName, let parentName = group.parentName {
                        Text(verbatim: L10n.Watch.Home.Device.partOf(parentName))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemSymbol: .chevronRight)
                    .font(.caption2.weight(.semibold))
            }
            // Without it only the glyphs are tappable, and a section header is a small target.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MaterialDesignIcons.register()
    return List {
        Section {
            Text(verbatim: "Ceiling")
        } header: {
            WatchAreaDeviceSectionHeader(
                group: .init(deviceId: "device-1", name: "Living Room Lamp", entries: []),
                serverId: "1"
            )
        }
        Section {
            Text(verbatim: "Outlet 2")
        } header: {
            WatchAreaDeviceSectionHeader(
                group: .init(
                    deviceId: "device-2",
                    name: "Outlet 2",
                    parentName: "Power strip",
                    entries: []
                ),
                serverId: "1"
            )
        }
    }
}
