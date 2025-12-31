import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct EntityMoreInfoDialogView: View {
    let server: Server
    let appEntity: HAAppEntity
    let haEntity: HAEntity?
    @Environment(\.dismiss) private var dismiss

    @State private var triggerHaptic = 0
    @State private var areaName: String = ""

    init(server: Server, appEntity: HAAppEntity, haEntity: HAEntity?) {
        self.server = server
        self.appEntity = appEntity
        self.haEntity = haEntity
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.three) {
                    switch Domain(entityId: appEntity.entityId) {
                    case .light:
                        lightControlsView
                    default:
                        Text("More controls coming soon")
                            .font(DesignSystem.Font.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DesignSystem.Spaces.four)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(appEntity.name)
            .navigationSubtitle(areaName)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
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
        }
    }

    // MARK: - Area Lookup

    private func loadAreaName() async {
        do {
            let areas = try AppArea.fetchAreas(
                containingEntity: appEntity.entityId,
                serverId: server.identifier.rawValue
            )
            if let area = areas.first {
                areaName = area.name
            }
        } catch {
            Current.Log.error("Failed to fetch area for entity \(appEntity.entityId): \(error.localizedDescription)")
        }
    }

    // MARK: - Domain-Specific Controls

    @ViewBuilder
    private var lightControlsView: some View {
        LightControlsView(
            server: server,
            appEntity: appEntity,
            haEntity: haEntity
        )
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    @Previewable @State var haEntity: HAEntity? = try? HAEntity(
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
        appEntity: appEntity,
        haEntity: haEntity
    )
}
