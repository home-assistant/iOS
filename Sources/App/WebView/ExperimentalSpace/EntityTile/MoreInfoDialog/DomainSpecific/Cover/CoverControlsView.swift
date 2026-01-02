import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct CoverControlsView: View {
    let haEntity: HAEntity?

    @State private var viewModel: CoverControlsViewModel
    @State private var localPosition: Double

    init(server: Server, appEntity: HAAppEntity, haEntity: HAEntity?) {
        self.haEntity = haEntity
        let vm = CoverControlsViewModel(
            server: server,
            appEntity: appEntity,
            haEntity: haEntity
        )
        self._viewModel = State(initialValue: vm)
        self._localPosition = State(initialValue: vm.currentPosition)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            // Header with state
            header

            // Main vertical slider for position control
            HStack(spacing: DesignSystem.Spaces.three) {
                Spacer()

                // Vertical slider
                VStack(spacing: DesignSystem.Spaces.two) {
                    VerticalSlider(
                        value: $localPosition,
                        in: 0 ... 100,
                        step: 1,
                        icon: viewModel.coverIcon,
                        tint: .blue,
                        trackWidth: 120,
                        thumbSize: 32,
                        showThumb: false,
                        shape: .capsule,
                        onEditingChanged: { isEditing in
                            if !isEditing {
                                // User finished dragging, send the position
                                Task {
                                    await viewModel.setCoverPosition(localPosition)
                                }
                            }
                        }
                    )
                    .frame(height: 400)
                    .disabled(viewModel.isUpdating)

                    Text("\(Int(localPosition))%")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Action buttons
            actionButtons
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spaces.two)
        .onAppear {
            viewModel.initialize()
            localPosition = viewModel.currentPosition
        }
        .onChange(of: haEntity) { _, newValue in
            viewModel.updateEntity(newValue)
            localPosition = viewModel.currentPosition
        }
        .onChange(of: viewModel.currentPosition) { _, newValue in
            // Sync slider with entity updates
            if !viewModel.isUpdating {
                localPosition = newValue
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(viewModel.stateDescription())
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: viewModel.currentPosition)

            if viewModel.deviceClass != .unknown {
                Text(viewModel.deviceClass.rawValue.capitalized)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        GlassEffectContainer(spacing: 20.0) {
            HStack(spacing: DesignSystem.Spaces.two) {
                // Close button
                Button {
                    Task {
                        await viewModel.closeCover()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemSymbol: .arrowDown)
                            .font(.system(size: 20, weight: .semibold))
                        Text("Close")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUpdating)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))

                // Stop button
                if viewModel.isOpening || viewModel.isClosing {
                    Button {
                        Task {
                            await viewModel.stopCover()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemSymbol: .stopFill)
                                .font(.system(size: 20, weight: .semibold))
                            Text("Stop")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isUpdating)
                    .glassEffect(.regular.tint(.orange).interactive(), in: .rect(cornerRadius: 16))
                }

                // Open button
                Button {
                    Task {
                        await viewModel.openCover()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemSymbol: .arrowUp)
                            .font(.system(size: 20, weight: .semibold))
                        Text("Open")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUpdating)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Cover Half Open") {
    @Previewable @State var haEntity: HAEntity? = try? HAEntity(
        entityId: "cover.living_room_blinds",
        domain: "cover",
        state: "open",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Blinds",
            "device_class": "blind",
            "current_position": 50,
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

    CoverControlsView(
        server: ServerFixture.standard,
        appEntity: appEntity,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Garage Door Open") {
    @Previewable @State var haEntity: HAEntity? = try? HAEntity(
        entityId: "cover.garage_door",
        domain: "cover",
        state: "open",
        lastChanged: Date().addingTimeInterval(-7200),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Garage Door",
            "device_class": "garage",
            "current_position": 100,
            "supported_features": 3,
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-cover.garage_door",
        entityId: "cover.garage_door",
        serverId: "test-server",
        domain: "cover",
        name: "Garage Door",
        icon: "mdi:garage",
        rawDeviceClass: "garage"
    )

    CoverControlsView(
        server: ServerFixture.standard,
        appEntity: appEntity,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Curtain Closing") {
    @Previewable @State var haEntity: HAEntity? = try? HAEntity(
        entityId: "cover.bedroom_curtain",
        domain: "cover",
        state: "closing",
        lastChanged: Date().addingTimeInterval(-10),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Bedroom Curtain",
            "device_class": "curtain",
            "current_position": 75,
            "supported_features": 15,
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-cover.bedroom_curtain",
        entityId: "cover.bedroom_curtain",
        serverId: "test-server",
        domain: "cover",
        name: "Bedroom Curtain",
        icon: "mdi:curtains",
        rawDeviceClass: "curtain"
    )

    CoverControlsView(
        server: ServerFixture.standard,
        appEntity: appEntity,
        haEntity: haEntity
    )
    .padding()
}
