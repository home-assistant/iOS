import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct SwitchControlsView: View {
    let haEntity: HAEntity?

    @State private var viewModel: SwitchControlsViewModel

    init(server: Server, appEntity: HAAppEntity, haEntity: HAEntity?) {
        self.haEntity = haEntity
        self._viewModel = State(initialValue: SwitchControlsViewModel(
            server: server,
            appEntity: appEntity,
            haEntity: haEntity
        ))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            // Header with state
            header
            Spacer()
            // Vertical switch control
            verticalSwitchControl
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spaces.two)
        .onAppear {
            viewModel.initialize()
        }
        .onChange(of: haEntity) { _, newValue in
            viewModel.updateEntity(newValue)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(viewModel.stateDescription())
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: viewModel.isOn)

            if let deviceClass = viewModel.deviceClass {
                Text(deviceClass.capitalized)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Vertical Switch Control

    private var verticalSwitchControl: some View {
        VerticalToggleControl(
            isOn: Binding(
                get: { viewModel.isOn },
                set: { newValue in
                    // Don't update directly, let the ViewModel handle it
                    if newValue != viewModel.isOn {
                        Task {
                            await viewModel.toggleSwitch()
                        }
                    }
                }
            ),
            icon: viewModel.switchIcon,
            isDisabled: viewModel.isUpdating
        )
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Switch On") {
    @Previewable @State var haEntity: HAEntity? = try? HAEntity(
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

    SwitchControlsView(
        server: ServerFixture.standard,
        appEntity: appEntity,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Switch Off") {
    @Previewable @State var haEntity: HAEntity? = try? HAEntity(
        entityId: "switch.living_room_fan",
        domain: "switch",
        state: "off",
        lastChanged: Date().addingTimeInterval(-7200),
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

    SwitchControlsView(
        server: ServerFixture.standard,
        appEntity: appEntity,
        haEntity: haEntity
    )
    .padding()
}
