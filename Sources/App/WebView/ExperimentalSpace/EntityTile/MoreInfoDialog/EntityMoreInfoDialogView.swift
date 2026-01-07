import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct EntityMoreInfoDialogView: View {
    let server: Server
    let haEntity: HAEntity
    @Environment(\.dismiss) private var dismiss

    @State private var triggerHaptic = 0
    @State private var areaName: String = ""
    @State private var showWebView = false

    init(server: Server, haEntity: HAEntity) {
        self.server = server
        self.haEntity = haEntity
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spaces.three) {
                switch Domain(entityId: haEntity.entityId) {
                case .light:
                    lightControlsView
                case .switch:
                    switchControlsView
                case .cover:
                    coverControlsView
                case .fan:
                    fanControlsView
                default:
                    Text("More controls coming soon")
                        .font(DesignSystem.Font.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DesignSystem.Spaces.four)
                }
            }
            .scrollClipDisabled()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(haEntity.attributes.friendlyName ?? haEntity.entityId)
            .navigationSubtitle(areaName)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWebView = true
                    } label: {
                        Image(systemSymbol: .gearshapeFill)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        triggerHaptic += 1
                        dismiss()
                    }
                }
            }
            .task {
                await loadAreaName()
            }
            .sheet(isPresented: $showWebView) {
                EntityConfigurationWebView(haEntity: haEntity, server: server, areaName: areaName)
            }
        }
    }

    // MARK: - Area Lookup

    private func loadAreaName() async {
        do {
            let areas = try AppArea.fetchAreas(
                containingEntity: haEntity.entityId,
                serverId: server.identifier.rawValue
            )
            if let area = areas.first {
                areaName = area.name
            }
        } catch {
            Current.Log.error("Failed to fetch area for entity \(haEntity.entityId): \(error.localizedDescription)")
        }
    }

    // MARK: - Domain-Specific Controls

    @ViewBuilder
    private var lightControlsView: some View {
        LightControlsView(
            server: server,
            haEntity: haEntity
        )
    }

    @ViewBuilder
    private var switchControlsView: some View {
        SwitchControlsView(
            server: server,
            haEntity: haEntity
        )
    }

    @ViewBuilder
    private var coverControlsView: some View {
        CoverControlsView(
            server: server,
            haEntity: haEntity
        )
    }

    @ViewBuilder
    private var fanControlsView: some View {
        FanControlsView(
            server: server,
            haEntity: haEntity
        )
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Light Entity") {
    @Previewable @State var haEntity: HAEntity! = try? HAEntity(
        entityId: "light.living_room",
        domain: "light",
        state: "on",
        lastChanged: Date(),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Light",
            "brightness": 200,
            "rgb_color": [255, 200, 100],
            "supported_color_modes": ["rgb", "brightness"],
            "color_mode": "rgb",
            "area_id": "living_room",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-light.living_room",
        entityId: "light.living_room",
        serverId: "test-server",
        domain: "light",
        name: "Living Room Light",
        icon: "mdi:lightbulb",
        rawDeviceClass: nil
    )

    EntityMoreInfoDialogView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
}

@available(iOS 26.0, *)
#Preview("Switch Entity") {
    @Previewable @State var haEntity: HAEntity! = try? HAEntity(
        entityId: "switch.living_room_fan",
        domain: "switch",
        state: "on",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Fan",
            "device_class": "outlet",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-switch.living_room_fan",
        entityId: "switch.living_room_fan",
        serverId: "test-server",
        domain: "switch",
        name: "Living Room Fan",
        icon: "mdi:fan",
        rawDeviceClass: "outlet"
    )

    EntityMoreInfoDialogView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
}

@available(iOS 26.0, *)
#Preview("Cover Entity") {
    @Previewable @State var haEntity: HAEntity! = try? HAEntity(
        entityId: "cover.living_room_blinds",
        domain: "cover",
        state: "open",
        lastChanged: Date().addingTimeInterval(-1800),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Blinds",
            "device_class": "blind",
            "current_position": 65,
            "supported_features": 15,
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-cover.living_room_blinds",
        entityId: "cover.living_room_blinds",
        serverId: "test-server",
        domain: "cover",
        name: "Living Room Blinds",
        icon: "mdi:blinds",
        rawDeviceClass: "blind"
    )

    EntityMoreInfoDialogView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
}

@available(iOS 26.0, *)
#Preview("Fan Entity") {
    @Previewable @State var haEntity: HAEntity! = try? HAEntity(
        entityId: "fan.living_room_fan",
        domain: "fan",
        state: "on",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Fan",
            "percentage": 75,
            "oscillating": true,
            "direction": "forward",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-fan.living_room_fan",
        entityId: "fan.living_room_fan",
        serverId: "test-server",
        domain: "fan",
        name: "Living Room Fan",
        icon: "mdi:fan",
        rawDeviceClass: nil
    )

    EntityMoreInfoDialogView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
}
