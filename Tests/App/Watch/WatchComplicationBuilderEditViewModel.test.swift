import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
@Suite(.serialized)
struct WatchComplicationBuilderEditViewModelTests {
    // MARK: - Initial state

    @Test func newConfigStartsWithNoSourceAndFirstServerPreselected() throws {
        try withBuilderTestWorld(serverIds: ["server-1", "server-2"]) { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)

            #expect(viewModel.isNew)
            #expect(viewModel.selectedSource == nil)
            #expect(viewModel.config.serverId == "server-1")
            #expect(!viewModel.isSourceConfigured)
            #expect(!viewModel.isValid)
        }
    }

    @Test func existingConfigStartsWithItsKindSelected() throws {
        try withBuilderTestWorld { _ in
            let existing = WatchComplicationConfig(
                serverId: "server-1",
                kind: .customTemplate,
                customTextTemplate: "{{ states('sensor.x') }}"
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)

            #expect(!viewModel.isNew)
            #expect(viewModel.selectedSource == .customTemplate)
            #expect(viewModel.isSourceConfigured)
            #expect(viewModel.isValid)
        }
    }

    // MARK: - Source selection

    @Test func selectSourceUpdatesConfigKind() throws {
        try withBuilderTestWorld { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)

            viewModel.selectSource(.customTemplate)
            #expect(viewModel.selectedSource == .customTemplate)
            #expect(viewModel.config.kind == .customTemplate)

            viewModel.selectSource(.entity)
            #expect(viewModel.selectedSource == .entity)
            #expect(viewModel.config.kind == .entity)
        }
    }

    @Test func switchingSourceKeepsPreviouslyEnteredValues() throws {
        try withBuilderTestWorld { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)
            viewModel.selectSource(.entity)
            viewModel.config.entityId = "sensor.battery"

            viewModel.selectSource(.customTemplate)
            #expect(viewModel.config.entityId == "sensor.battery")
            // Template not entered yet, so the template flow is not configured/valid…
            #expect(!viewModel.isSourceConfigured)
            #expect(!viewModel.isValid)

            // …but switching back to entity is immediately configured again.
            viewModel.selectSource(.entity)
            #expect(viewModel.isSourceConfigured)
            #expect(viewModel.isValid)
        }
    }

    // MARK: - Server selection

    @Test func selectServerClearsEntityFromPreviousServer() throws {
        try withBuilderTestWorld(serverIds: ["server-1", "server-2"]) { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)
            viewModel.selectSource(.entity)
            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1")
            viewModel.applySelectedEntity()
            #expect(viewModel.config.entityId == "sensor.battery")

            viewModel.selectServer("server-2")
            #expect(viewModel.config.serverId == "server-2")
            #expect(viewModel.config.entityId == nil)
            #expect(viewModel.config.entityDisplayName == nil)
            #expect(viewModel.selectedEntity == nil)
        }
    }

    @Test func reselectingSameServerKeepsEntity() throws {
        try withBuilderTestWorld { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)
            viewModel.selectSource(.entity)
            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1")
            viewModel.applySelectedEntity()

            viewModel.selectServer("server-1")
            #expect(viewModel.config.entityId == "sensor.battery")
            #expect(viewModel.selectedEntity != nil)
        }
    }

    // MARK: - Entity auto-design

    @Test func pickingEntityAppliesAutoDesignDefaults() throws {
        try withBuilderTestWorld { _ in
            // No gauge range set, so the battery device class should default to 0–100.
            let existing = WatchComplicationConfig(serverId: "server-1")
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)
            viewModel.config.valueAttribute = "voltage"

            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1", icon: nil)
            viewModel.applySelectedEntity()

            #expect(viewModel.config.entityId == "sensor.battery")
            #expect(viewModel.config.entityDisplayName == "Battery")
            // The old value source no longer applies to the new entity.
            #expect(viewModel.config.valueAttribute == nil)
            // No entity icon, so the domain/device-class fallback is applied.
            let fallbackIcon = Domain(rawValue: "sensor")?.icon(deviceClass: "battery").name
            #expect(viewModel.config.iconName == fallbackIcon)
            #expect(viewModel.config.iconName != nil)
            // Percentage-like device class defaults to a 0–100 gauge.
            #expect(viewModel.config.gaugeMin == 0)
            #expect(viewModel.config.gaugeMax == 100)
        }
    }

    @Test func pickingEntityPrefersItsOwnIcon() throws {
        try withBuilderTestWorld { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)

            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1", icon: "mdi:flash")
            viewModel.applySelectedEntity()

            #expect(viewModel.config.iconName == "mdi:flash")
        }
    }

    @Test func pickingEntityKeepsUserGaugeRange() throws {
        try withBuilderTestWorld { _ in
            // The new-config defaults include a 0–100 range; picking a battery must not reset a range
            // the config already has.
            let existing = WatchComplicationConfig(serverId: "server-1", gaugeMin: 20, gaugeMax: 80)
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)

            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1")
            viewModel.applySelectedEntity()

            #expect(viewModel.config.gaugeMin == 20)
            #expect(viewModel.config.gaugeMax == 80)
        }
    }

    @Test func rehydratingSameEntityDoesNotClobberSavedDesign() throws {
        try withBuilderTestWorld { _ in
            // Reopening the editor hydrates `selectedEntity` for the already-configured entity; that
            // must not re-run the auto-design and overwrite the user's saved icon/name.
            let existing = WatchComplicationConfig(
                serverId: "server-1",
                entityId: "sensor.battery",
                entityDisplayName: "My custom name",
                iconName: "mdi:custom-icon"
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)

            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1", icon: "mdi:battery")
            viewModel.applySelectedEntity()

            #expect(viewModel.config.iconName == "mdi:custom-icon")
            #expect(viewModel.config.entityDisplayName == "My custom name")
        }
    }

    @Test func clearingEntityClearsSubtitle() throws {
        try withBuilderTestWorld { _ in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)
            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1")
            viewModel.applySelectedEntity()

            viewModel.selectedEntity = nil
            viewModel.applySelectedEntity()
            #expect(viewModel.entitySubtitle == nil)
        }
    }

    // MARK: - Hydration

    @Test func hydrateSelectedEntityFetchesFromDatabase() throws {
        try withBuilderTestWorld { database in
            let entity = Self.batteryEntity(serverId: "server-1")
            try database.write { db in try entity.insert(db) }

            let existing = WatchComplicationConfig(serverId: "server-1", entityId: "sensor.battery")
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)
            viewModel.hydrateSelectedEntity()

            #expect(viewModel.selectedEntity == entity)
        }
    }

    // MARK: - Template color

    @Test func templateColorOptInFollowsExistingConfig() throws {
        try withBuilderTestWorld { _ in
            // Any one of the three color templates counts as opted in.
            let existing = WatchComplicationConfig(
                serverId: "server-1",
                kind: .customTemplate,
                customTextTemplate: "{{ 1 }}",
                customIconColorTemplate: "{{ '#FF0000' }}"
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)
            #expect(viewModel.useTemplateColor)
            #expect(WatchComplicationBuilderEditViewModel(existing: nil).useTemplateColor == false)
        }
    }

    @Test func disablingTemplateColorClearsAllColorTemplates() throws {
        try withBuilderTestWorld { _ in
            let existing = WatchComplicationConfig(
                serverId: "server-1",
                kind: .customTemplate,
                customTextTemplate: "{{ 1 }}",
                customGaugeColorTemplate: "{{ '#00FF00' }}",
                customIconColorTemplate: "{{ '#0000FF' }}",
                customTextColorTemplate: "{{ '#FF0000' }}"
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)

            viewModel.useTemplateColor = false
            #expect(viewModel.config.customGaugeColorTemplate == nil)
            #expect(viewModel.config.customIconColorTemplate == nil)
            #expect(viewModel.config.customTextColorTemplate == nil)
        }
    }

    // MARK: - Custom colors

    @Test func customColorsToggleReadsBackFromTheStoredColors() throws {
        try withBuilderTestWorld { _ in
            // Any stored color reads as "on" — the toggle describes the complication, nothing else.
            let iconColor = WatchComplicationConfig(serverId: "server-1", iconColor: "#FF0000")
            #expect(WatchComplicationBuilderEditViewModel(existing: iconColor).useCustomColors)

            let familyColor = WatchComplicationConfig(
                serverId: "server-1",
                families: ["circular": .init(textColor: "#00FF00")]
            )
            #expect(WatchComplicationBuilderEditViewModel(existing: familyColor).useCustomColors)

            // Template-driven colors count too — otherwise the toggle hid the template fields that
            // were actually coloring the complication.
            let templateColor = WatchComplicationConfig(
                serverId: "server-1",
                kind: .customTemplate,
                customTextTemplate: "{{ 1 }}",
                customTextColorTemplate: "{{ '#FF0000' }}"
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: templateColor)
            #expect(viewModel.useCustomColors)
            #expect(viewModel.useTemplateColor)

            let noColors = WatchComplicationConfig(serverId: "server-1")
            #expect(WatchComplicationBuilderEditViewModel(existing: noColors).useCustomColors == false)
        }
    }

    @Test func disablingCustomColorsClearsEveryStoredColor() throws {
        try withBuilderTestWorld { _ in
            let existing = WatchComplicationConfig(
                serverId: "server-1",
                kind: .customTemplate,
                iconColor: "#FF0000",
                customTextTemplate: "{{ 1 }}",
                customGaugeColorTemplate: "{{ '#00FF00' }}",
                families: [
                    "circular": .init(tint: "#0000FF", textColor: "#FFFFFF"),
                    "rectangular": .init(showIcon: true, tint: "#AABBCC"),
                ]
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: existing)
            #expect(viewModel.useCustomColors)

            viewModel.useCustomColors = false

            #expect(viewModel.config.iconColor == nil)
            #expect(viewModel.config.customGaugeColorTemplate == nil)
            #expect(viewModel.config.customIconColorTemplate == nil)
            #expect(viewModel.config.customTextColorTemplate == nil)
            #expect(viewModel.config.families?["circular"]?.tint == nil)
            #expect(viewModel.config.families?["circular"]?.textColor == nil)
            #expect(viewModel.config.families?["rectangular"]?.tint == nil)
            // Only the colors are cleared — the other per-size options survive.
            #expect(viewModel.config.families?["rectangular"]?.showIcon == true)
            #expect(viewModel.useTemplateColor == false)
        }
    }

    @Test func disablingCustomColorsSurvivesSaveAndReopen() throws {
        try withBuilderTestWorld { database in
            // The bug this guards: turning the toggle off left the colors on the row, so the saved
            // complication stayed tinted and the editor reopened with the toggle back on.
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)
            viewModel.selectSource(.entity)
            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1")
            viewModel.applySelectedEntity()
            viewModel.config.iconColor = "#FF0000"
            viewModel.save()

            var saved = try database.read { db in
                try WatchComplicationConfig.fetchOne(db, key: viewModel.config.id)
            }
            #expect(WatchComplicationBuilderEditViewModel(existing: saved).useCustomColors)

            viewModel.useCustomColors = false
            viewModel.save()

            saved = try database.read { db in
                try WatchComplicationConfig.fetchOne(db, key: viewModel.config.id)
            }
            #expect(saved?.iconColor == nil)
            #expect(WatchComplicationBuilderEditViewModel(existing: saved).useCustomColors == false)
        }
    }

    @Test func normalizedHexColorAcceptsValidHexOnly() {
        #expect(WatchComplicationConfig.normalizedHexColor(from: "#ff9500") == "#FF9500")
        #expect(WatchComplicationConfig.normalizedHexColor(from: "ff9500") == "#FF9500")
        #expect(WatchComplicationConfig.normalizedHexColor(from: "  '#FF9500AA'  ") == "#FF9500AA")
        #expect(WatchComplicationConfig.normalizedHexColor(from: "\"#64D2FF\"") == "#64D2FF")
        #expect(WatchComplicationConfig.normalizedHexColor(from: "red") == nil)
        #expect(WatchComplicationConfig.normalizedHexColor(from: "#FF95") == nil)
        #expect(WatchComplicationConfig.normalizedHexColor(from: "") == nil)
    }

    // MARK: - Save

    @Test func savePersistsConfigAndPostsChangeNotification() throws {
        try withBuilderTestWorld { database in
            let viewModel = WatchComplicationBuilderEditViewModel(existing: nil)
            viewModel.selectSource(.entity)
            viewModel.selectedEntity = Self.batteryEntity(serverId: "server-1")
            viewModel.applySelectedEntity()

            var notified = false
            let token = NotificationCenter.default.addObserver(
                forName: WatchComplicationConfig.didChangeNotification,
                object: nil,
                queue: nil
            ) { _ in notified = true }
            defer { NotificationCenter.default.removeObserver(token) }

            viewModel.save()

            let saved = try database.read { db in
                try WatchComplicationConfig.fetchOne(db, key: viewModel.config.id)
            }
            #expect(saved?.entityId == "sensor.battery")
            #expect(saved?.kind == .entity)
            #expect(notified)
        }
    }

    // MARK: - Helpers

    private static func batteryEntity(serverId: String, icon: String? = nil) -> HAAppEntity {
        HAAppEntity(
            id: "\(serverId)-sensor.battery",
            entityId: "sensor.battery",
            serverId: serverId,
            domain: "sensor",
            name: "Battery",
            icon: icon,
            rawDeviceClass: "battery"
        )
    }

    private func withBuilderTestWorld<T>(
        serverIds: [String] = ["server-1"],
        perform work: @MainActor (DatabaseQueue) throws -> T
    ) throws -> T {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }

        let previousDatabase = Current.database
        let previousServers = Current.servers

        let servers = FakeServerManager(initial: 0)
        for serverId in serverIds {
            servers.add(identifier: .init(rawValue: serverId), serverInfo: .fake())
        }

        Current.database = { database }
        Current.servers = servers

        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        return try work(database)
    }
}
