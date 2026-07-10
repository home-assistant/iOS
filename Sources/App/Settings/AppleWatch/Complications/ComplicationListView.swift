import GRDB
import Shared
import SwiftUI
import UIKit

/// Root of the Complications settings screen. Mirrors the CarPlay / Widgets configuration layout:
/// an Apple-like header, the list of the user's complications with an add button, and the legacy
/// complications tucked behind a navigation link.
struct ComplicationsRootView: View {
    @State private var configs: [WatchComplicationConfig] = []
    @State private var editing: WatchComplicationConfig?
    @State private var showAdd = false

    var body: some View {
        List {
            header
            yourComplicationsSection

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
        .navigationTitle(L10n.Watch.Complications.Builder.title)
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
                        ComplicationFamilyPreview(family: config.widgetFamily)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading) {
                            Text(config.displayName)
                                .foregroundColor(.primary)
                            Text(verbatim: config.widgetFamily.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

    private func reload() {
        configs = (try? WatchComplicationConfig.all()) ?? []
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
    @StateObject private var viewModel = ComplicationListViewModel()
    @State private var showFamilyPicker = false

    var body: some View {
        List {
            introSection
            manualUpdatesSection
            groupSections
            #if DEBUG
            // Creating new legacy (ClockKit-era) complications is retained for debugging only; users
            // build complications through the modern entity/template builder on the root screen.
            addSection
            #endif
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

    private var introSection: some View {
        Section {
            Text(L10n.Watch.Configurator.List.description)
                .foregroundColor(.primary)
            Link(destination: URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!) {
                HStack {
                    Text(L10n.Nfc.List.learnMore)
                    Spacer()
                    Image(systemSymbol: .arrowUpForwardSquare)
                        .font(.caption)
                }
            }
            Text(L10n.Watch.Configurator.Warning.templatingAdmin)
                .foregroundColor(.secondary)
        }
    }

    private var manualUpdatesSection: some View {
        Section {
            HStack {
                Text(L10n.Watch.Configurator.List.ManualUpdates.remaining)
                Spacer()
                Text(viewModel.remainingUpdatesDescription)
                    .foregroundColor(.secondary)
            }
            LoadingButton(
                title: L10n.Watch.Configurator.List.ManualUpdates.manuallyUpdate,
                isLoading: viewModel.isUpdatingComplications
            ) {
                viewModel.updateComplications()
            }
        } header: {
            Text(L10n.Watch.Configurator.List.ManualUpdates.title)
        } footer: {
            Text(L10n.Watch.Configurator.List.ManualUpdates.footer)
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

    private var showGaugeBinding: Binding<Bool> {
        Binding(
            get: { config.showsGauge(for: currentFamily) },
            set: { value in updateOptions { $0.showGauge = value } }
        )
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
            get: { config.tint(for: currentFamily).map { Color(uiColor: UIColor($0)) } ?? .green },
            set: { value in updateOptions { $0.tint = UIColor(value).hexString(true) } }
        )
    }

    var body: some View {
        Form {
            if let server {
                Section {
                    WatchComplicationLivePreview(config: config, server: server)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color(uiColor: .systemBackground))
                    Picker(selection: $config.widgetFamily) {
                        ForEach(WatchComplicationConfig.Family.allCases) { family in
                            Text(verbatim: family.title).tag(family)
                        }
                    } label: {
                        Text(L10n.Watch.Complications.Builder.previewSize)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(L10n.Watch.Complications.Builder.preview)
                } footer: {
                    Text(L10n.Watch.Complications.Builder.previewFooter)
                }
            }

            Section {
                // Name first; when left blank the complication falls back to the entity's name, so the
                // placeholder previews that fallback.
                TextField(text: stringBinding(\.name)) {
                    Text(verbatim: namePlaceholder)
                }

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

                    EntityPicker(
                        selectedServerId: config.serverId,
                        selectedEntity: $selectedEntity,
                        domainFilter: nil,
                        mode: .button
                    )
                    // Recreate when the server changes so the picker fetches that server's entities.
                    .id(config.serverId)
                    .disabled(config.serverId.isEmpty)

                    if let entitySubtitle {
                        Text(verbatim: entitySubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if config.kind == .entity {
                // Per-size customization: bound to the size currently selected in the preview above.
                Section {
                    Toggle(isOn: showValueBinding) { Text(L10n.Watch.Complications.Builder.showValue) }
                    Toggle(isOn: showGaugeBinding) { Text(L10n.Watch.Complications.Builder.showGauge) }
                    if config.showsGauge(for: config.widgetFamily) {
                        numberField(title: L10n.Watch.Complications.Builder.minimum, value: gaugeMinBinding)
                        numberField(title: L10n.Watch.Complications.Builder.maximum, value: gaugeMaxBinding)
                    }
                    ColorPicker(
                        L10n.Watch.Complications.Builder.color,
                        selection: tintBinding,
                        supportsOpacity: false
                    )
                } header: {
                    Text(L10n.Watch.Complications.Builder.sizeOptions(config.widgetFamily.title))
                } footer: {
                    Text(L10n.Watch.Complications.Builder.sizeOptionsFooter)
                }
            } else {
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
        }
        .navigationTitle(Text(isNew ? L10n.Watch.Complications.Builder.newTitle : L10n.Watch.Complications.Builder
                .editTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.saveLabel) { save() }.disabled(!isValid)
            }
        }
        .onChange(of: selectedEntity?.id) { _ in
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
        let text = Binding<String>(
            get: { value.wrappedValue.map { String($0) } ?? "" },
            set: { value.wrappedValue = Double($0) }
        )
        HStack {
            Text(verbatim: title)
            Spacer()
            TextField(text: text) { Text(verbatim: "—") }
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
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

/// A live approximation of the watch complication, mirroring `WatchWidgetsEntryView` but rendered on
/// iPhone with current data (via Home Assistant template rendering) so the user sees the real result
/// before saving. Not pixel-identical to watchOS, but faithful to layout, icon, value and gauge.
struct WatchComplicationLivePreview: View {
    let config: WatchComplicationConfig
    @StateObject private var valueRenderer: TemplateRenderer
    @StateObject private var gaugeRenderer: TemplateRenderer

    init(config: WatchComplicationConfig, server: Server) {
        self.config = config
        _valueRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
        _gaugeRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
    }

    private var name: String {
        config.name ?? config.entityDisplayName ?? config.entityId ?? ""
    }

    private var value: String {
        if case let .success(rendered) = valueRenderer.output, !rendered.isEmpty {
            return rendered
        }
        return ""
    }

    private var fraction: Double? {
        guard case let .success(rendered) = gaugeRenderer.output,
              let raw = WatchComplication.percentileNumber(from: rendered) else {
            return nil
        }
        return min(max(Double(raw), 0), 1)
    }

    private var tint: Color {
        config.tint(for: config.widgetFamily).map { Color(uiColor: UIColor($0)) } ?? .accentColor
    }

    private var showsValue: Bool { config.showsValue(for: config.widgetFamily) }

    private var iconImage: Image? {
        guard let iconName = config.iconName else { return nil }
        let image = MaterialDesignIcons(named: iconName)
            .image(ofSize: CGSize(width: 64, height: 64), color: .white)
        return Image(uiImage: image)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .onAppear(perform: applyTemplates)
            .onChange(of: config) { _ in applyTemplates() }
    }

    @ViewBuilder
    private var content: some View {
        switch config.widgetFamily {
        case .circular, .corner:
            circular
        case .rectangular:
            rectangular
        case .inline:
            inline
        }
    }

    private var circular: some View {
        ZStack {
            Circle().fill(Color.black)
            if let fraction {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                iconImage?
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                if showsValue, !value.isEmpty {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .padding(20)
        }
        .frame(width: 100, height: 100)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            iconImage?
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(showsValue && !value.isEmpty ? value : " ")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black))
        .foregroundStyle(.white)
    }

    private var inline: some View {
        HStack(spacing: 4) {
            iconImage?.resizable().scaledToFit().frame(width: 16, height: 16)
            Text([name, showsValue ? value : ""].filter { !$0.isEmpty }.joined(separator: " "))
                .font(.system(size: 15)).lineLimit(1)
        }
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
                return
            }
            // Value with unit, mirroring the watch (which also applies registry precision).
            valueRenderer.updateTemplate(
                "{{ states('\(entityId)') }}{{ ' ' ~ state_attr('\(entityId)', 'unit_of_measurement') " +
                    "if state_attr('\(entityId)', 'unit_of_measurement') else '' }}"
            )
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
        }
    }
}

#Preview {
    NavigationView { ComplicationsRootView() }
}
