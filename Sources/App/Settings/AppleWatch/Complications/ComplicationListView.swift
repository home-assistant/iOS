import GRDB
import Shared
import SwiftUI
import UIKit

/// Root of the Complications settings screen. Mirrors the CarPlay / Widgets configuration layout:
/// an Apple-like header, the list of the user's complications with an add button, and the legacy
/// complications tucked behind a navigation link.
struct ComplicationsRootView: View {
    @State private var configs: [WatchComplicationConfig] = []
    /// Context line per config (entity `Area • Device`, or "Template"), computed off the DB in `reload`.
    @State private var subtitles: [String: String] = [:]
    /// Whether any legacy (ClockKit-era) complications exist — the legacy link is hidden otherwise.
    @State private var hasLegacy = false
    @State private var editing: WatchComplicationConfig?
    @State private var showAdd = false

    var body: some View {
        List {
            header
            yourComplicationsSection

            Section {
                Button {
                    HomeAssistantAPI.syncWatchContext()
                } label: {
                    Label(L10n.Watch.Complications.Root.reload, systemSymbol: .arrowClockwise)
                }
            } footer: {
                Text(L10n.Watch.Complications.Root.reloadFooter)
            }

            if hasLegacy {
                Section {
                    NavigationLink {
                        ComplicationListView()
                    } label: {
                        Label(title: { Text(L10n.Watch.Complications.Root.legacy) },
                              icon: { Image(systemSymbol: .clockArrowCirclepath) })
                    }
                } footer: {
                    Text(L10n.Watch.Complications.Root.legacyFooter)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationView { WatchComplicationBuilderEditView(existing: nil) }
        }
        .sheet(item: $editing) { config in
            NavigationView { WatchComplicationBuilderEditView(existing: config) }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: WatchComplicationConfig.didChangeNotification)) { _ in
            reload()
        }
    }

    private var header: some View {
        AppleLikeListTopRowHeader(
            image: .watchVariantIcon,
            title: L10n.Watch.Complications.Builder.title,
            subtitle: L10n.Watch.Complications.Root.headerSubtitle
        )
    }

    private var yourComplicationsSection: some View {
        Section(L10n.Watch.Complications.Root.yourComplications) {
            ForEach(configs) { config in
                Button {
                    editing = config
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        rowIcon(for: config)
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading) {
                            Text(config.displayName)
                                .foregroundColor(.primary)
                            if let subtitle = subtitles[config.id] {
                                Text(verbatim: subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    // Make the whole row (including empty space) tappable, not just the text.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)

            Button {
                showAdd = true
            } label: {
                Label(L10n.Watch.Complications.Root.new, systemSymbol: .plus)
            }
        }
    }

    /// A plain MDI icon for entity-backed complications, or a gauge glyph as a neutral fallback for
    /// template-backed (or icon-less) ones — not a per-family mock, since a complication works in every size.
    private func rowIcon(for config: WatchComplicationConfig) -> Image {
        let color = config.iconColor.map { UIColor(hex: $0) } ?? AppConstants.tintColor
        let icon: MaterialDesignIcons
        if config.kind == .entity, let iconName = config.iconName {
            // Icon names may be server-side values (e.g. "mdi:home"); normalize before lookup.
            icon = MaterialDesignIcons(serversideValueNamed: iconName)
        } else {
            icon = .gaugeIcon
        }
        return Image(uiImage: icon.image(ofSize: .init(width: 28, height: 28), color: color))
    }

    private func reload() {
        hasLegacy = !((try? WatchComplication.all()) ?? []).isEmpty
        let all = (try? WatchComplicationConfig.all()) ?? []
        configs = all
        var map: [String: String] = [:]
        for config in all {
            switch config.kind {
            case .entity:
                guard let entityId = config.entityId else { continue }
                let key = "\(config.serverId)-\(entityId)"
                let entity = try? Current.database().read { db in
                    try HAAppEntity.fetchOne(db, key: key)
                }
                map[config.id] = entity?.contextualSubtitle ?? config.entityDisplayName ?? entityId
            case .customTemplate:
                map[config.id] = L10n.Watch.Complications.Root.template
            }
        }
        subtitles = map
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? configs[index].delete()
        }
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        HomeAssistantAPI.syncWatchContext()
        reload()
    }
}

/// SwiftUI replacement for `ComplicationListViewController`.
struct ComplicationListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ComplicationListViewModel()
    @State private var showFamilyPicker = false
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        List {
            groupSections
            #if DEBUG
            // Creating new legacy (ClockKit-era) complications is retained for debugging only; users
            // build complications through the modern entity/template builder on the root screen.
            addSection
            #endif
            deleteAllSection
        }
        .navigationTitle(Text(L10n.Watch.Complications.Legacy.title))
        .sheet(isPresented: $showFamilyPicker) {
            NavigationView {
                ComplicationFamilySelectView(
                    allowMultiple: viewModel.supportsMultipleComplications,
                    currentFamilies: viewModel.currentFamilies,
                    onSaved: { showFamilyPicker = false }
                )
            }
            .navigationViewStyle(.stack)
        }
        .alert(
            L10n.errorLabel,
            isPresented: $viewModel.showError,
            presenting: viewModel.errorMessage
        ) { _ in
            Button(L10n.okLabel, role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Sections

    private var deleteAllSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                Text(L10n.Watch.Complications.Legacy.deleteAll)
            }
            .confirmationDialog(
                L10n.Watch.Complications.Legacy.deleteAllConfirm,
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    viewModel.deleteAll()
                    // Nothing left to configure here; return to the root, where the legacy entry hides.
                    dismiss()
                } label: {
                    Text(L10n.Watch.Complications.Legacy.deleteAll)
                }
                Button(role: .cancel) {} label: { Text(L10n.cancelLabel) }
            }
        }
    }

    @ViewBuilder
    private var groupSections: some View {
        ForEach(ComplicationGroup.allCases.sorted(), id: \.self) { group in
            if let items = viewModel.complicationsByGroup[group], !items.isEmpty {
                Section {
                    ForEach(items, id: \.identifier) { complication in
                        NavigationLink {
                            ComplicationEditView(
                                config: complication,
                                isNew: false,
                                onSaved: nil
                            )
                        } label: {
                            HStack {
                                Text(complication.Family.shortName)
                                Spacer()
                                Text(complication.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(group.name)
                } footer: {
                    Text(group.description)
                }
            }
        }
    }

    #if DEBUG
    private var addSection: some View {
        Section {
            Button(L10n.addButtonLabel) {
                showFamilyPicker = true
            }
        }
    }
    #endif
}

// MARK: - New (modern) complication builder

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
    @State private var showEntityPicker = false
    private let isNew: Bool

    init(existing: WatchComplicationConfig?) {
        isNew = existing == nil
        let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
        _config = State(initialValue: existing ?? WatchComplicationConfig(serverId: serverId))
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

    /// Unit visibility is global (the value text is shared across sizes).
    private var showUnitBinding: Binding<Bool> {
        Binding(
            get: { config.showsUnit() },
            set: { config.showUnit = $0 }
        )
    }

    /// Whether the complication is shown while the watch display is dimmed (global).
    private var showWhenInactiveBinding: Binding<Bool> {
        Binding(
            get: { config.showsWhenInactive() },
            set: { config.showWhenInactive = $0 }
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
                    WatchComplicationLivePreview(config: config, server: server) { unit in
                        entityUnit = unit
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color(uiColor: .systemBackground))
                    .listRowSeparator(.hidden)
                    Picker(selection: $config.widgetFamily) {
                        ForEach(WatchComplicationConfig.Family.allCases) { family in
                            Text(verbatim: family.title).tag(family)
                        }
                    } label: {
                        Text(L10n.Watch.Complications.Builder.previewSize)
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
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

            // Per-size display options, bound to the size currently selected in the header picker.
            Section {
                Toggle(isOn: showNameBinding) { Text(L10n.Watch.Complications.Builder.showName) }
                Toggle(isOn: showValueBinding) { Text(L10n.Watch.Complications.Builder.showValue) }
                // Inline has no icon.
                if currentFamily != .inline {
                    Toggle(isOn: showIconBinding) { Text(L10n.Watch.Complications.Builder.showIcon) }
                }
                if config.kind == .entity, entityUnit != nil {
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

            // Colors for the selected size. Inline is rendered in the watch-face tint, so it has none.
            if currentFamily != .inline {
                Section {
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
                } header: {
                    Text(L10n.Watch.Complications.Builder.colors)
                }
            }

            Section {
                Toggle(isOn: showWhenInactiveBinding) {
                    Text(L10n.Watch.Complications.Builder.showWhenInactive)
                }
            } footer: {
                Text(L10n.Watch.Complications.Builder.showWhenInactiveFooter)
            }

            // Mirror of the top preview so the result is visible from the bottom of the form too.
            if let server {
                Section {
                    WatchComplicationLivePreview(config: config, server: server)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color(uiColor: .systemBackground))
                        .listRowSeparator(.hidden)
                }
            }
        }
        .navigationTitle(Text(isNew ? L10n.Watch.Complications.Builder.newTitle : L10n.Watch.Complications.Builder
                .editTitle))
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
            config.entityId = entity.entityId
            config.entityDisplayName = entity.name
            entitySubtitle = entity.contextualSubtitle
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

// MARK: - Mock family previews (Phase E)

/// A small styled mock of how each WidgetKit accessory family looks, used in the builder.
struct ComplicationFamilyPreview: View {
    let family: WatchComplicationConfig.Family

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch family {
                case .circular:
                    Circle().stroke(Color.accentColor, lineWidth: side * 0.12)
                    Image(systemSymbol: .houseFill).font(.system(size: side * 0.32))
                case .corner:
                    Circle()
                        .trim(from: 0.5, to: 0.75)
                        .stroke(Color.accentColor, lineWidth: side * 0.12)
                    Image(systemSymbol: .houseFill).font(.system(size: side * 0.22))
                case .rectangular:
                    RoundedRectangle(cornerRadius: side * 0.12)
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    VStack(alignment: .leading, spacing: side * 0.06) {
                        Capsule().fill(Color.accentColor).frame(width: side * 0.7, height: side * 0.12)
                        Capsule().fill(Color.secondary.opacity(0.5)).frame(width: side * 0.5, height: side * 0.1)
                    }
                    .padding(side * 0.12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .inline:
                    Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    Capsule().fill(Color.accentColor).frame(width: side * 0.6, height: side * 0.12)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// A horizontal progress bar with a circular value "thumb" riding the fill, and the minimum / maximum
/// labels below the bar.
struct RectangularGauge: View {
    let fraction: Double
    let minLabel: String?
    let maxLabel: String?
    let valueLabel: String?
    let tint: Color

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.25)).frame(height: RectangularGaugeMetrics.barHeight)
                    Capsule().fill(tint)
                        .frame(
                            width: max(RectangularGaugeMetrics.barHeight, width * clamped),
                            height: RectangularGaugeMetrics.barHeight
                        )
                    if let valueLabel {
                        RectangularGaugeThumb(value: valueLabel, tint: tint)
                            .position(
                                x: min(
                                    max(width * clamped, RectangularGaugeMetrics.thumbSize / 2),
                                    width - RectangularGaugeMetrics.thumbSize / 2
                                ),
                                y: RectangularGaugeMetrics.thumbSize / 2
                            )
                    }
                }
                .frame(height: RectangularGaugeMetrics.thumbSize)
            }
            .frame(height: RectangularGaugeMetrics.thumbSize)
            HStack {
                Text(verbatim: minLabel ?? " ")
                Spacer()
                Text(verbatim: maxLabel ?? " ")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }
}

enum RectangularGaugeMetrics {
    static let barHeight: CGFloat = 7
    static let thumbSize: CGFloat = 22
}

/// Circular value marker for the rectangular progress bar: a filled disc in the bar's color with the
/// value inside, in a contrast-aware color.
struct RectangularGaugeThumb: View {
    let value: String
    let tint: Color

    /// Black on light tints, white on dark ones.
    private var contrastColor: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tint).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? .black : .white
    }

    var body: some View {
        ZStack {
            Circle().fill(tint)
            Text(verbatim: value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(contrastColor)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(1)
        }
        .frame(width: RectangularGaugeMetrics.thumbSize, height: RectangularGaugeMetrics.thumbSize)
    }
}

/// A live approximation of the watch complication, mirroring `WatchWidgetsEntryView` but rendered on
/// iPhone with current data (via Home Assistant template rendering) so the user sees the real result
/// before saving. Not pixel-identical to watchOS, but faithful to layout, icon, value and gauge.
struct WatchComplicationLivePreview: View {
    let config: WatchComplicationConfig
    /// Reports the entity's rendered unit of measurement (nil when it has none) so the editor can
    /// decide whether to offer the "Show unit" toggle.
    var onUnit: (String?) -> Void = { _ in }
    @StateObject private var valueRenderer: TemplateRenderer
    @StateObject private var gaugeRenderer: TemplateRenderer
    @StateObject private var unitRenderer: TemplateRenderer

    init(config: WatchComplicationConfig, server: Server, onUnit: @escaping (String?) -> Void = { _ in }) {
        self.config = config
        self.onUnit = onUnit
        _valueRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
        _gaugeRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
        _unitRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
    }

    private var name: String {
        config.name ?? config.entityDisplayName ?? config.entityId ?? ""
    }

    private var renderedValue: String {
        if case let .success(rendered) = valueRenderer.output { return rendered }
        return ""
    }

    private var renderedUnit: String? {
        if case let .success(unit) = unitRenderer.output, !unit.isEmpty { return unit }
        return nil
    }

    /// The value as displayed: appends the unit when present and enabled (entity source only).
    private var value: String {
        let base = renderedValue
        guard !base.isEmpty else { return "" }
        if config.kind == .entity, config.showsUnit(), let unit = renderedUnit {
            return "\(base) \(unit)"
        }
        return base
    }

    private var fraction: Double? {
        guard case let .success(rendered) = gaugeRenderer.output,
              let raw = WatchComplication.percentileNumber(from: rendered) else {
            return nil
        }
        return min(max(Double(raw), 0), 1)
    }

    private var showsGauge: Bool { config.showsGauge(for: config.widgetFamily) && fraction != nil }

    private var range: (min: Double, max: Double)? { config.gaugeRange(for: config.widgetFamily) }

    private var tint: Color {
        config.tint(for: config.widgetFamily).map { Color(uiColor: UIColor($0)) } ?? .accentColor
    }

    /// Value/text color; defaults to white for contrast on the dark preview face.
    private var textColor: Color {
        config.textColor(for: config.widgetFamily).map { Color(uiColor: UIColor(hex: $0)) } ?? .white
    }

    private var showsValue: Bool { config.showsValue(for: config.widgetFamily) }

    private var showsName: Bool { config.showsName(for: config.widgetFamily) }

    private var showsIcon: Bool { config.showsIcon(for: config.widgetFamily) }

    private var showsMin: Bool { config.showsMin(for: config.widgetFamily) }

    private var showsMax: Bool { config.showsMax(for: config.widgetFamily) }

    private var iconColor: Color {
        config.iconColor.map { Color(uiColor: UIColor(hex: $0)) } ?? .white
    }

    private var iconImage: Image? {
        guard showsIcon, let iconName = config.iconName else { return nil }
        let image = MaterialDesignIcons(serversideValueNamed: iconName)
            .image(ofSize: CGSize(width: 64, height: 64), color: UIColor(iconColor))
        return Image(uiImage: image)
    }

    /// True while any of the template renderers is still evaluating.
    private var isLoading: Bool {
        [valueRenderer.output, gaugeRenderer.output, unitRenderer.output].contains(.loading)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .onAppear(perform: applyTemplates)
            .onChange(of: config) { _ in applyTemplates() }
            .onChange(of: unitRenderer.output) { _ in onUnit(renderedUnit) }
    }

    @ViewBuilder
    private var content: some View {
        switch config.widgetFamily {
        case .circular:
            circular
        case .corner:
            corner
        case .rectangular:
            rectangular
        case .inline:
            inline
        }
    }

    /// Corner: content tucked in the screen corner with a curved gauge along the bezel. Approximated
    /// here with the value above a linear gauge, anchored to the bottom of the face.
    private var corner: some View {
        ZStack {
            Circle().fill(Color.black)
            VStack(spacing: 2) {
                Spacer()
                iconImage?
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                if showsValue, !value.isEmpty {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                if showsGauge, let fraction {
                    Gauge(value: fraction) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(tint)
                        .frame(width: 66)
                }
            }
            .padding(12)
        }
        .frame(width: 100, height: 100)
        .environment(\.colorScheme, .dark)
    }

    /// Icon / value / name shown in the middle of a circular complication, each per its toggle.
    private var centerContent: some View {
        VStack(spacing: 0) {
            iconImage?
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            if showsValue, !value.isEmpty {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if showsName, !name.isEmpty {
                Text(name)
                    .font(.system(size: 9))
                    .foregroundStyle(textColor.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    /// Uses the real WidgetKit accessory gauge styles so the preview matches watchOS: an open arc
    /// (with min/max labels) or a full capacity ring, otherwise just the icon/value.
    @ViewBuilder
    private var circular: some View {
        ZStack {
            Circle().fill(Color.black)
            Group {
                if showsGauge, let fraction {
                    switch config.gaugeStyle(for: config.widgetFamily) {
                    case .open:
                        Gauge(value: fraction) {
                            EmptyView()
                        } currentValueLabel: {
                            centerContent
                        } minimumValueLabel: {
                            Text(verbatim: (showsMin ? range.map { label($0.min) } : nil) ?? "")
                        } maximumValueLabel: {
                            Text(verbatim: (showsMax ? range.map { label($0.max) } : nil) ?? "")
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(tint)
                    case .capacity:
                        Gauge(value: fraction) {
                            EmptyView()
                        } currentValueLabel: {
                            centerContent
                        }
                        .gaugeStyle(.accessoryCircularCapacity)
                        .tint(tint)
                    }
                } else {
                    centerContent
                }
            }
            .padding(12)
        }
        .frame(width: 100, height: 100)
        .environment(\.colorScheme, .dark)
    }

    private func label(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            iconImage?
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                if showsName {
                    Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1).foregroundStyle(textColor)
                }
                if showsGauge, let fraction {
                    RectangularGauge(
                        fraction: fraction,
                        minLabel: showsMin ? range.map { label($0.min) } : nil,
                        maxLabel: showsMax ? range.map { label($0.max) } : nil,
                        valueLabel: showsValue && !value.isEmpty ? value : nil,
                        tint: tint
                    )
                } else if showsValue, !value.isEmpty {
                    Text(value).font(.system(size: 13)).foregroundStyle(textColor.opacity(0.85)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black))
    }

    private var inline: some View {
        // Inline has no icon or custom colors; name and value are joined with " - ".
        Text([showsName ? name : "", showsValue ? value : ""].filter { !$0.isEmpty }.joined(separator: " - "))
            .font(.system(size: 15)).lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.black))
    }

    private func applyTemplates() {
        switch config.kind {
        case .entity:
            guard let entityId = config.entityId else {
                valueRenderer.updateTemplate("")
                gaugeRenderer.updateTemplate("")
                unitRenderer.updateTemplate("")
                return
            }
            valueRenderer.updateTemplate("{{ states('\(entityId)') }}")
            unitRenderer.updateTemplate("{{ state_attr('\(entityId)', 'unit_of_measurement') or '' }}")
            if let range = config.gaugeRange(for: config.widgetFamily) {
                let source = config.gaugeAttribute(for: config.widgetFamily)
                    .map { "state_attr('\(entityId)', '\($0)')" } ?? "states('\(entityId)')"
                gaugeRenderer.updateTemplate(
                    "{{ ((\(source) | float(0)) - \(range.min)) / \(range.max - range.min) }}"
                )
            } else {
                gaugeRenderer.updateTemplate("")
            }
        case .customTemplate:
            valueRenderer.updateTemplate(config.customTextTemplate ?? "")
            gaugeRenderer.updateTemplate(config.customGaugeTemplate ?? "")
            unitRenderer.updateTemplate("")
        }
    }
}

#Preview {
    NavigationView { ComplicationsRootView() }
}
