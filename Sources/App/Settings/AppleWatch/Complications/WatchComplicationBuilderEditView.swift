import GRDB
import Shared
import SwiftUI
import UIKit

/// Add/edit a modern complication: pick an entity (auto-designed) or a custom template.
struct WatchComplicationBuilderEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: WatchComplicationConfig
    @State private var selectedEntity: HAAppEntity?
    /// Cached context line for the selected entity — computed off the DB, so kept out of `body`.
    @State private var entitySubtitle: String?
    /// The selected entity's unit of measurement (nil when it has none), reported by the live preview.
    /// Used to decide whether to offer the "Show unit" toggle.
    @State private var entityUnit: String?
    /// The selected entity's attribute names, reported by the live preview, offered as value sources.
    @State private var entityAttributeKeys: [String] = []
    @State private var showEntityPicker = false
    /// Whether the current value is numeric (reported by the preview) — gates the decimals picker.
    @State private var valueIsNumeric = false
    /// Progressive disclosure: the per-size option toggles are hidden behind "Customize" so the initial
    /// screen (name + source) stays simple for the average user.
    @State private var isCustomizing: Bool
    /// Nested opt-in under "Customize": reveals the color pickers.
    @State private var useCustomColors: Bool
    /// Whether the inline preview row is on screen. Form recycles offscreen rows, so the row's
    /// appear/disappear tracks scrolling; while it's away the preview floats over the form instead.
    @State private var isInlinePreviewVisible = true
    private let isNew: Bool

    init(existing: WatchComplicationConfig?) {
        self.isNew = existing == nil
        let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
        let initial = existing ?? WatchComplicationConfig(
            serverId: serverId,
            gaugeMin: 0,
            gaugeMax: 100,
            showMin: false,
            showMax: false
        )
        _config = State(initialValue: initial)
        // Reopen expanded when the user left Customize on (or, for configs saved before the flag
        // existed, when per-size customization is present).
        _isCustomizing = State(initialValue: initial.showsCustomized())
        _useCustomColors = State(
            initialValue: initial.iconColor != nil
                || (initial.families?.values.contains { $0.tint != nil || $0.textColor != nil } ?? false)
        )
    }

    private var server: Server? {
        Current.servers.all.first { $0.identifier.rawValue == config.serverId } ?? Current.servers.all.first
    }

    private var servers: [Server] { Current.servers.all }

    /// The Name field placeholder: the selected entity's name (so a blank name previews the fallback),
    /// otherwise the generic "Name" label.
    private var namePlaceholder: String {
        config.entityDisplayName ?? config.entityId ?? L10n.Watch.Complications.Builder.name
    }

    /// Server selection. Changing servers clears the entity, which belonged to the previous server.
    private var serverBinding: Binding<String> {
        Binding(
            get: { config.serverId },
            set: { newValue in
                guard newValue != config.serverId else { return }
                config.serverId = newValue
                selectedEntity = nil
                config.entityId = nil
                config.entityDisplayName = nil
            }
        )
    }

    /// The size currently selected in the preview — also the size being customized below.
    private var currentFamily: WatchComplicationConfig.Family { config.widgetFamily }

    private func updateOptions(_ mutate: (inout WatchComplicationConfig.FamilyOptions) -> Void) {
        var options = config.options(for: currentFamily)
        mutate(&options)
        config.setOptions(options, for: currentFamily)
    }

    private var showValueBinding: Binding<Bool> {
        Binding(
            get: { config.showsValue(for: currentFamily) },
            set: { value in updateOptions { $0.showValue = value } }
        )
    }

    private var showNameBinding: Binding<Bool> {
        Binding(
            get: { config.showsName(for: currentFamily) },
            set: { value in updateOptions { $0.showName = value } }
        )
    }

    private var showIconBinding: Binding<Bool> {
        Binding(
            get: { config.showsIcon(for: currentFamily) },
            set: { value in updateOptions { $0.showIcon = value } }
        )
    }

    private var showGaugeBinding: Binding<Bool> {
        Binding(
            get: { config.showsGauge(for: currentFamily) },
            set: { value in updateOptions { $0.showGauge = value } }
        )
    }

    private var showMinBinding: Binding<Bool> {
        Binding(
            get: { config.showsMin(for: currentFamily) },
            set: { value in updateOptions { $0.showMin = value } }
        )
    }

    private var showMaxBinding: Binding<Bool> {
        Binding(
            get: { config.showsMax(for: currentFamily) },
            set: { value in updateOptions { $0.showMax = value } }
        )
    }

    /// Icon color is global (not per-size); defaults to the Home Assistant primary color.
    private var iconColorBinding: Binding<Color> {
        Binding(
            get: { iconColor },
            set: { config.iconColor = UIColor($0).hexString(true) }
        )
    }

    /// Only the circular family has the open/ring gauge; the others (except inline) show a progress bar.
    private var familyHasProgressBar: Bool { currentFamily != .inline }

    private var gaugeToggleTitle: String {
        currentFamily == .circular
            ? L10n.Watch.Complications.Builder.showGauge
            : L10n.Watch.Complications.Builder.showProgressBar
    }

    private var gaugeColorTitle: String {
        currentFamily == .circular
            ? L10n.Watch.Complications.Builder.color
            : L10n.Watch.Complications.Builder.progressBarColor
    }

    private var gaugeMinBinding: Binding<Double?> {
        Binding(
            get: { config.families?[currentFamily.rawValue]?.gaugeMin ?? config.gaugeMin },
            set: { value in updateOptions { $0.gaugeMin = value } }
        )
    }

    private var gaugeMaxBinding: Binding<Double?> {
        Binding(
            get: { config.families?[currentFamily.rawValue]?.gaugeMax ?? config.gaugeMax },
            set: { value in updateOptions { $0.gaugeMax = value } }
        )
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: { config.tint(for: currentFamily).map { Color(uiColor: UIColor($0)) } ?? Color.haPrimary },
            set: { value in updateOptions { $0.tint = UIColor(value).hexString(true) } }
        )
    }

    /// The icon's tint, used for the icon picker preview. Defaults to the Home Assistant primary color.
    private var iconColor: Color {
        config.iconColor.map { Color(uiColor: UIColor(hex: $0)) } ?? Color.haPrimary
    }

    /// Two-way binding between the stored (possibly server-side "mdi:") icon name and the icon picker.
    private var iconBinding: Binding<MaterialDesignIcons?> {
        Binding(
            get: { config.iconName.map { MaterialDesignIcons(serversideValueNamed: $0) } },
            set: { config.iconName = $0?.name }
        )
    }

    /// Value source: empty string == the entity state, otherwise an attribute name. Global (the value
    /// text is shared across sizes).
    private var valueAttributeBinding: Binding<String> {
        Binding(
            get: { config.valueAttribute ?? "" },
            set: { config.valueAttribute = $0.isEmpty ? nil : $0 }
        )
    }

    /// Decimal precision override: `-1` (the picker's "Automatic") maps to nil, meaning follow Home
    /// Assistant's display precision.
    private var valuePrecisionBinding: Binding<Int> {
        Binding(
            get: { config.valuePrecision ?? -1 },
            set: { config.valuePrecision = $0 < 0 ? nil : $0 }
        )
    }

    /// Unit visibility is global (the value text is shared across sizes).
    private var showUnitBinding: Binding<Bool> {
        Binding(
            get: { config.showsUnit() },
            set: { config.showUnit = $0 }
        )
    }

    private var gaugeStyleBinding: Binding<WatchComplicationConfig.GaugeStyle> {
        Binding(
            get: { config.gaugeStyle(for: currentFamily) },
            set: { value in updateOptions { $0.gaugeStyle = value.rawValue } }
        )
    }

    /// Text/value color; defaults to primary when unset.
    private var textColorBinding: Binding<Color> {
        Binding(
            get: { config.textColor(for: currentFamily).map { Color(uiColor: UIColor(hex: $0)) } ?? .primary },
            set: { value in updateOptions { $0.textColor = UIColor(value).hexString(true) } }
        )
    }

    var body: some View {
        Form {
            if let server {
                Section {
                    AllFamiliesComplicationPreview(
                        config: config,
                        server: server,
                        selectedFamily: $config.widgetFamily,
                        onUnit: { entityUnit = $0 },
                        onAttributes: { entityAttributeKeys = $0 },
                        onValueIsNumeric: { valueIsNumeric = $0 }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.vertical, DesignSystem.Spaces.one)
                    .onAppear {
                        withAnimation { isInlinePreviewVisible = true }
                    }
                    .onDisappear {
                        withAnimation { isInlinePreviewVisible = false }
                    }
                } header: {
                    Text(L10n.Watch.Complications.Builder.preview)
                } footer: {
                    Text(L10n.Watch.Complications.Builder.previewFooter)
                }
            }

            Section {
                // Icon + name on one row, matching MagicItemCustomizationView. The icon is auto-derived
                // from the entity and can be overridden here; a blank name falls back to the entity name.
                HStack(spacing: DesignSystem.Spaces.two) {
                    IconPicker(
                        selectedIcon: iconBinding,
                        selectedColor: iconColorBinding
                    )
                    TextField(text: stringBinding(\.name)) {
                        Text(verbatim: namePlaceholder)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text(L10n.Watch.Complications.Builder.displayName)
            }

            Section {
                Picker(selection: $config.kind) {
                    Text(L10n.Watch.Complications.Builder.sourceEntity).tag(WatchComplicationConfig.Kind.entity)
                    Text(L10n.Watch.Complications.Builder.sourceCustom).tag(WatchComplicationConfig.Kind.customTemplate)
                } label: {
                    Text(L10n.Watch.Complications.Builder.source)
                }

                if config.kind == .entity {
                    // Server selector — only meaningful with more than one server; the entity picker
                    // reads from (and is scoped to) the selected server.
                    if servers.count > 1 {
                        Picker(selection: serverBinding) {
                            ForEach(servers, id: \.identifier.rawValue) { server in
                                Text(verbatim: server.info.name).tag(server.identifier.rawValue)
                            }
                        } label: {
                            Text(L10n.AppIntents.Server.title)
                        }
                    }

                    // Entity + its context as one row (name primary, context as subtitle); opens the
                    // full picker in a sheet.
                    Button {
                        showEntityPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                Text(verbatim: selectedEntity?.name ?? L10n.EntityPicker.placeholder)
                                    .foregroundColor(.accentColor)
                                if let entitySubtitle {
                                    Text(verbatim: entitySubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(config.serverId.isEmpty)
                    .sheet(isPresented: $showEntityPicker) {
                        NavigationView {
                            EntityPicker(
                                selectedServerId: config.serverId,
                                selectedEntity: $selectedEntity,
                                domainFilter: nil,
                                mode: .list
                            )
                        }
                        .navigationViewStyle(.stack)
                    }

                    // Choose whether the value shown is the entity's state or one of its attributes.
                    if config.entityId != nil, !entityAttributeKeys.isEmpty {
                        Picker(selection: valueAttributeBinding) {
                            Text(L10n.Watch.Complications.Builder.valueSourceState).tag("")
                            ForEach(entityAttributeKeys, id: \.self) { key in
                                Text(verbatim: key).tag(key)
                            }
                        } label: {
                            Text(L10n.Watch.Complications.Builder.valueSource)
                        }
                    }

                    // Decimal precision for a numeric value. A picker (not free text) so there is nothing
                    // to validate; "Automatic" follows Home Assistant, and the initial selection is seeded
                    // with Home Assistant's current precision when the entity is chosen.
                    if config.entityId != nil {
                        // Decimals only make sense for a numeric value; hidden for string states
                        // (e.g. "home", "on").
                        if valueIsNumeric {
                            Picker(selection: valuePrecisionBinding) {
                                Text(L10n.Watch.Complications.Builder.precisionAutomatic).tag(-1)
                                ForEach(0 ... 4, id: \.self) { number in
                                    Text(verbatim: "\(number)").tag(number)
                                }
                            } label: {
                                Text(L10n.Watch.Complications.Builder.precision)
                            }
                        }

                        // Optional custom unit; the placeholder shows the auto-resolved unit, so leaving
                        // it blank keeps following Home Assistant.
                        HStack {
                            Text(L10n.Watch.Complications.Builder.unit)
                            Spacer()
                            TextField(text: stringBinding(\.unitOverride)) {
                                Text(verbatim: entityUnit ?? L10n.Watch.Complications.Builder.unitAutomatic)
                            }
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        }
                    }
                }
            }

            if config.kind == .customTemplate {
                Section {
                    TextField(text: stringBinding(\.customTextTemplate)) {
                        Text(verbatim: "{{ states('sensor.x') }}")
                    }
                    TextField(text: stringBinding(\.customGaugeTemplate)) {
                        Text(verbatim: "{{ … }} → 0–1")
                    }
                } header: {
                    Text(L10n.Watch.Complications.Builder.templates)
                }
            }

            // Progressive disclosure: keep the initial screen simple (name + source). Everything below
            // is opt-in behind "Customize", so the average user isn't faced with a crowded form.
            Section {
                Toggle(isOn: $isCustomizing.animation()) { Text(L10n.Watch.Complications.Builder.customize) }
                    // Mirror into the config so saving persists the disclosure state (feedback:
                    // "Customize was always off when reopening the editor").
                    .onChange(of: isCustomizing) { newValue in config.isCustomized = newValue }
            } footer: {
                Text(L10n.Watch.Complications.Builder.customizeFooter)
            }

            if isCustomizing {
                // Per-size display options, bound to the size selected in the preview above.
                Section {
                    Toggle(isOn: showNameBinding) { Text(L10n.Watch.Complications.Builder.showName) }
                    Toggle(isOn: showValueBinding) { Text(L10n.Watch.Complications.Builder.showValue) }
                    // Inline has no icon.
                    if currentFamily != .inline {
                        Toggle(isOn: showIconBinding) { Text(L10n.Watch.Complications.Builder.showIcon) }
                    }
                    if config.kind == .entity, entityUnit != nil || !(config.unitOverride ?? "").isEmpty {
                        Toggle(isOn: showUnitBinding) { Text(L10n.Watch.Complications.Builder.showUnit) }
                    }

                    if familyHasProgressBar {
                        Toggle(isOn: showGaugeBinding) { Text(verbatim: gaugeToggleTitle) }
                        if config.showsGauge(for: currentFamily) {
                            // Only the circular gauge has an open/ring style choice.
                            if currentFamily == .circular {
                                Picker(selection: gaugeStyleBinding) {
                                    ForEach(WatchComplicationConfig.GaugeStyle.allCases) { style in
                                        Text(verbatim: style.title).tag(style)
                                    }
                                } label: {
                                    Text(L10n.Watch.Complications.GaugeStyle.title)
                                }
                                .pickerStyle(.segmented)
                            }
                            // Numeric range + min/max labels only apply to entity gauges.
                            if config.kind == .entity {
                                numberField(title: L10n.Watch.Complications.Builder.minimum, value: gaugeMinBinding)
                                numberField(title: L10n.Watch.Complications.Builder.maximum, value: gaugeMaxBinding)
                                if config.gaugeRange(for: currentFamily) != nil {
                                    Toggle(isOn: showMinBinding) {
                                        Text(L10n.Watch.Complications.Builder.showMin)
                                    }
                                    Toggle(isOn: showMaxBinding) {
                                        Text(L10n.Watch.Complications.Builder.showMax)
                                    }
                                }
                            }
                        }
                    }

                } header: {
                    // Family switcher, so the size being customized can be changed without scrolling
                    // back up to the preview.
                    Picker(selection: $config.widgetFamily) {
                        ForEach(WatchComplicationConfig.Family.allCases) { family in
                            Text(verbatim: family.title).tag(family)
                        }
                    } label: { EmptyView() }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                        .textCase(nil)
                        .padding(.bottom, DesignSystem.Spaces.one)
                } footer: {
                    Text(L10n.Watch.Complications.Builder.sizeOptionsFooter)
                }

                // Colors are a further opt-in under Customize. Inline is rendered in the watch-face tint,
                // so it has no custom colors.
                if currentFamily != .inline {
                    Section {
                        Toggle(isOn: $useCustomColors.animation()) {
                            Text(L10n.Watch.Complications.Builder.customColors)
                        }
                        if useCustomColors {
                            if familyHasProgressBar, config.showsGauge(for: currentFamily) {
                                ColorPicker(gaugeColorTitle, selection: tintBinding, supportsOpacity: false)
                            }
                            if config.showsIcon(for: currentFamily) {
                                ColorPicker(
                                    L10n.Watch.Complications.Builder.iconColor,
                                    selection: iconColorBinding,
                                    supportsOpacity: false
                                )
                            }
                            ColorPicker(
                                L10n.Watch.Complications.Builder.textColor,
                                selection: textColorBinding,
                                supportsOpacity: false
                            )
                        }
                    } header: {
                        Text(L10n.Watch.Complications.Builder.colors)
                    }
                }
            } // end if isCustomizing
        }
        // Once the inline preview scrolls away, it re-appears as a floating mini preview — only the
        // selected size, zoomed to fit a small watch screen — that the user can drag to any corner
        // and tap (or pinch) to resize, so the live preview stays visible while editing options
        // further down the form.
        .overlay {
            if let server, !isInlinePreviewVisible {
                FloatingPanel(
                    initialCorner: .topTrailing,
                    initialScale: 1,
                    minScale: 0.55,
                    // Concentric with the fake watch bezel: its radius plus the panel's content padding.
                    cornerRadius: AllFamiliesComplicationPreview.compactBezelCornerRadius + DesignSystem.Spaces.one
                ) {
                    AllFamiliesComplicationPreview(
                        config: config,
                        server: server,
                        selectedFamily: $config.widgetFamily,
                        showsOnlySelectedFamily: true,
                        onUnit: { entityUnit = $0 },
                        onAttributes: { entityAttributeKeys = $0 },
                        onValueIsNumeric: { valueIsNumeric = $0 }
                    )
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .navigationTitle(Text(
            isNew ? L10n.Watch.Complications.Builder.newTitle : L10n.Watch.Complications.Builder
                .editTitle
        ))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if #available(iOS 26.0, *) {
                    Button(role: .close) { dismiss() }
                } else {
                    Button { dismiss() } label: { Image(systemSymbol: .xmark) }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if #available(iOS 26.0, *) {
                    Button(role: .confirm) { save() }.disabled(!isValid)
                } else {
                    Button { save() } label: { Image(systemSymbol: .checkmark) }
                        .disabled(!isValid)
                }
            }
        }
        .onChange(of: selectedEntity?.id) { _ in
            // Dismiss the picker sheet once a choice is made.
            showEntityPicker = false
            guard let entity = selectedEntity else {
                entitySubtitle = nil
                return
            }
            entitySubtitle = entity.contextualSubtitle
            // Only auto-design defaults when the user actually picked a *different* entity. On appear we
            // hydrate `selectedEntity` from the existing config, which also fires this handler — without
            // this guard that would clobber the user's saved icon/name/gauge every time they reopen the
            // editor (feedback: "icon not saving correctly").
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
        .onAppear {
            if selectedEntity == nil, let entityId = config.entityId {
                let key = "\(config.serverId)-\(entityId)"
                selectedEntity = try? Current.database().read { db in
                    try HAAppEntity.fetchOne(db, key: key)
                }
            }
            entitySubtitle = selectedEntity?.contextualSubtitle
        }
    }

    private var isValid: Bool {
        switch config.kind {
        case .entity: return config.entityId != nil
        case .customTemplate: return !(config.customTextTemplate ?? "").isEmpty
        }
    }

    private func save() {
        do {
            try config.save()
        } catch {
            Current.Log.error("Failed to save complication config: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        HomeAssistantAPI.syncWatchContext()
        WatchMirrorPushCoordinator.schedule(reason: .complicationChanged)
        dismiss()
    }

    private func stringBinding(_ keyPath: WritableKeyPath<WatchComplicationConfig, String?>) -> Binding<String> {
        Binding(
            get: { config[keyPath: keyPath] ?? "" },
            set: { config[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder
    private func numberField(title: String, value: Binding<Double?>) -> some View {
        // Min/max are whole numbers: display and accept integers only.
        let text = Binding<String>(
            get: { value.wrappedValue.map { String(Int($0.rounded())) } ?? "" },
            set: { value.wrappedValue = Int($0).map(Double.init) }
        )
        HStack {
            Text(verbatim: title)
            Spacer()
            TextField(text: text) { Text(verbatim: "—") }
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            #if !targetEnvironment(macCatalyst)
                .keyboardType(.numberPad)
            #endif
        }
    }
}

#Preview("Complication builder") {
    // Previews have no onboarded server; without one, `server` is nil and the preview section is
    // hidden. Seed a fake so the whole form (including the complication mock) renders.
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    return NavigationView { WatchComplicationBuilderEditView(existing: nil) }
}
