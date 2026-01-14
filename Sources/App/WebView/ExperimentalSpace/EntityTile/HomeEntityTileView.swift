import AppIntents
import HAKit
import Shared
import SwiftUI

/// Entity tile view specifically designed for use in HomeView
/// Handles business logic like device class lookup, icon color computation,
/// app intents integration, and more info dialog presentation
@available(iOS 26.0, *)
struct HomeEntityTileView: View {
    let server: Server
    let haEntity: HAEntity

    @Namespace private var namespace
    @State private var iconColor: Color = .secondary
    @State private var showMoreInfoDialog = false
    @State private var deviceClass: DeviceClass = .unknown

    init(server: Server, haEntity: HAEntity) {
        self.server = server
        self.haEntity = haEntity
    }

    var body: some View {
        EntityTileView(
            entityName: entityName,
            entityState: entityState,
            icon: icon,
            iconColor: iconColor,
            isUnavailable: isUnavailable,
            onIconTap: handleIconTap,
            onTileTap: handleTileTap
        )
        .onChange(of: haEntity) { _, _ in
            updateIconColor()
        }
        .onAppear {
            getDeviceClass()
            updateIconColor()
        }
        .matchedTransitionSource(id: haEntity.entityId, in: namespace)
        .fullScreenCover(isPresented: $showMoreInfoDialog) {
            EntityMoreInfoDialogView(
                server: server, 
                haEntity: haEntity
            )
            .navigationTransition(.zoom(sourceID: haEntity.entityId, in: namespace))
        }
    }

    // MARK: - Computed Properties

    private var entityName: String {
        haEntity.attributes.friendlyName ?? haEntity.entityId
    }

    private var entityState: String {
        Domain(entityId: haEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity.state
    }

    private var icon: MaterialDesignIcons {
        if let entityIcon = haEntity.attributes.icon {
            return MaterialDesignIcons(serversideValueNamed: entityIcon)
        } else if let domain = Domain(entityId: haEntity.entityId) {
            let stateString = haEntity.state
            let domainState = Domain.State(rawValue: stateString) ?? .unknown
            return domain.icon(deviceClass: deviceClass.rawValue, state: domainState)
        } else {
            return .homeIcon
        }
    }

    private var isUnavailable: Bool {
        let state = haEntity.state.lowercased()
        return [Domain.State.unavailable.rawValue, Domain.State.unknown.rawValue].contains(state)
    }

    // MARK: - Actions

    private func handleIconTap() {
        #if os(iOS)
        // Execute the app intent for the entity
        let intent = AppIntentProvider.intent(for: haEntity, server: server)
        Task {
            _ = try? await intent.perform()
        }
        #endif
    }

    private func handleTileTap() {
        showMoreInfoDialog = true
    }

    // MARK: - Business Logic

    private func getDeviceClass() {
        deviceClass = DeviceClassProvider.deviceClass(
            for: haEntity.entityId,
            serverId: server.identifier.rawValue
        )
    }

    private func updateIconColor() {
        let state = haEntity.state
        let colorMode = haEntity.attributes["color_mode"] as? String
        let rgbColor = haEntity.attributes["rgb_color"] as? [Int]
        let hsColor = haEntity.attributes["hs_color"] as? [Double]

        if isUnavailable {
            iconColor = .gray
            return
        }

        iconColor = EntityIconColorProvider.iconColor(
            domain: Domain(entityId: haEntity.entityId) ?? .switch,
            state: state,
            colorMode: colorMode,
            rgbColor: rgbColor,
            hsColor: hsColor
        )
    }
}
