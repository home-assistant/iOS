import Foundation
import GRDB
import Shared
import SwiftUI

/// Holds the builder's state and business rules — source/server/entity selection, the entity
/// auto-design defaults, and the save side effects — so `WatchComplicationBuilderEditView` stays
/// presentational and the rules stay unit-testable.
@MainActor
final class WatchComplicationBuilderEditViewModel: ObservableObject {
    @Published var config: WatchComplicationConfig
    @Published var selectedEntity: HAAppEntity?
    /// Cached context line for the selected entity — computed off the DB, so kept out of the view body.
    @Published private(set) var entitySubtitle: String?
    /// The selected entity's unit of measurement (nil when it has none), reported by the live preview.
    /// Used to decide whether to offer the unit field and the "Show unit" toggle.
    @Published var entityUnit: String?
    /// The selected entity's attribute names, reported by the live preview, offered as value sources.
    @Published var entityAttributeKeys: [String] = []
    /// Whether the current value is numeric (reported by the preview) — gates the decimals picker.
    @Published var valueIsNumeric = false
    /// The source (entity vs. template) picked in the radio cards at the top of the form. `nil` for a
    /// brand-new complication, so the form reveals itself step by step: source → server → entity /
    /// template → value options. Editing an existing config starts with its kind selected.
    @Published private(set) var selectedSource: WatchComplicationConfig.Kind?
    /// Progressive disclosure: the per-size option toggles are hidden behind "Customize" so the
    /// initial screen stays simple for the average user. Mirrored into the config so saving persists
    /// the disclosure state (feedback: "Customize was always off when reopening the editor").
    @Published var isCustomizing: Bool {
        didSet { config.isCustomized = isCustomizing }
    }

    /// Nested opt-in under "Customize": reveals the color pickers.
    @Published var useCustomColors: Bool
    /// Opt-in for the template flow: the colors come from templates rendering hex strings — one per
    /// static color picker. Turning it off clears the stored templates so the static colors apply
    /// again.
    @Published var useTemplateColor: Bool {
        didSet {
            guard !useTemplateColor else { return }
            config.customGaugeColorTemplate = nil
            config.customIconColorTemplate = nil
            config.customTextColorTemplate = nil
        }
    }

    let isNew: Bool

    init(existing: WatchComplicationConfig?) {
        self.isNew = existing == nil
        // The first server is pre-selected so the flow never starts without one; with a single
        // server the picker is omitted entirely, with several the user can switch it in the flow.
        let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
        let initial = existing ?? WatchComplicationConfig(
            serverId: serverId,
            gaugeMin: 0,
            gaugeMax: 100,
            showMin: false,
            showMax: false
        )
        self.config = initial
        self.selectedSource = existing?.kind
        // Reopen expanded when the user left Customize on (or, for configs saved before the flag
        // existed, when per-size customization is present).
        self.isCustomizing = initial.showsCustomized()
        self.useCustomColors = initial.iconColor != nil
            || (initial.families?.values.contains { $0.tint != nil || $0.textColor != nil } ?? false)
        self.useTemplateColor = [
            initial.customGaugeColorTemplate, initial.customIconColorTemplate, initial.customTextColorTemplate,
        ].contains { !($0 ?? "").isEmpty }
    }

    var server: Server? {
        Current.servers.all.first { $0.identifier.rawValue == config.serverId } ?? Current.servers.all.first
    }

    var servers: [Server] { Current.servers.all }

    /// The Name field placeholder: the selected entity's name (so a blank name previews the fallback),
    /// otherwise the generic "Name" label.
    var namePlaceholder: String {
        config.entityDisplayName ?? config.entityId ?? L10n.Watch.Complications.Builder.name
    }

    var isValid: Bool {
        switch config.kind {
        case .entity: return config.entityId != nil
        case .customTemplate: return !(config.customTextTemplate ?? "").isEmpty
        }
    }

    /// Whether the chosen source has everything it needs (an entity picked, or a template entered) —
    /// gates the shared display options (name/icon, Customize) at the bottom of the flow.
    var isSourceConfigured: Bool {
        switch selectedSource {
        case .entity: return config.entityId != nil
        case .customTemplate: return !(config.customTextTemplate ?? "").isEmpty
        case nil: return false
        }
    }

    func selectSource(_ kind: WatchComplicationConfig.Kind) {
        guard selectedSource != kind else { return }
        selectedSource = kind
        config.kind = kind
    }

    /// Server selection. Changing servers clears the entity, which belonged to the previous server.
    func selectServer(_ serverId: String) {
        guard serverId != config.serverId else { return }
        config.serverId = serverId
        selectedEntity = nil
        config.entityId = nil
        config.entityDisplayName = nil
    }

    /// Applies `selectedEntity` to the config. Auto-design defaults (icon, precision, gauge) only
    /// run when the user actually picked a *different* entity: rehydrating on appear also lands here,
    /// and without the guard it would clobber the user's saved icon/name/gauge every time they reopen
    /// the editor (feedback: "icon not saving correctly").
    func applySelectedEntity() {
        guard let entity = selectedEntity else {
            entitySubtitle = nil
            return
        }
        entitySubtitle = entity.contextualSubtitle
        guard entity.entityId != config.entityId else { return }
        config.entityId = entity.entityId
        config.entityDisplayName = entity.name
        // A new entity's value source no longer applies to the old attributes.
        config.valueAttribute = nil
        // Seed the precision override with Home Assistant's current display precision, so the picker
        // starts on the value HA uses (the user can then override it or pick Automatic).
        config.valuePrecision = EntityRegistryListForDisplay.Entity.displayPrecision(
            serverId: config.serverId,
            entityId: entity.entityId
        )
        // Prefer the entity's own icon; otherwise fall back to a domain/device-class default so the
        // complication isn't icon-less on the watch.
        config.iconName = entity.icon
            ?? Domain(rawValue: entity.domain)?.icon(deviceClass: entity.rawDeviceClass).name
        // Percentage-like entities read naturally as a ring, so default to a 0–100 gauge (unless the
        // user already set a range) — this is why picking a battery immediately shows a ring.
        if config.gaugeMin == nil, config.gaugeMax == nil,
           [.battery, .humidity, .moisture].contains(entity.deviceClass) {
            config.gaugeMin = 0
            config.gaugeMax = 100
        }
    }

    /// Rehydrates the picked entity from the database when the editor opens on an existing config.
    func hydrateSelectedEntity() {
        if selectedEntity == nil, let entityId = config.entityId {
            let key = "\(config.serverId)-\(entityId)"
            selectedEntity = try? Current.database().read { db in
                try HAAppEntity.fetchOne(db, key: key)
            }
        }
        entitySubtitle = selectedEntity?.contextualSubtitle
    }

    func save() {
        autoGenerateNameIfNeeded()
        do {
            try config.save()
        } catch {
            Current.Log.error("Failed to save complication config: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        HomeAssistantAPI.syncWatchContext()
        WatchMirrorPushCoordinator.schedule(reason: .complicationChanged)
    }

    /// A template complication saved without a name gets "Complication-N" (first free number), so it
    /// never shows up as a generic "Complication" in the iOS list and the watch gallery. Entity
    /// complications keep their entity-name fallback instead.
    private func autoGenerateNameIfNeeded() {
        guard config.kind == .customTemplate,
              (config.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let existingNames = Set(((try? WatchComplicationConfig.all()) ?? []).compactMap(\.name))
        var number = 1
        while existingNames.contains("Complication-\(number)") {
            number += 1
        }
        config.name = "Complication-\(number)"
    }
}
