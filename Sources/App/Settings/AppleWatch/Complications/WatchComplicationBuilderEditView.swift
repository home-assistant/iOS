import Shared
import SwiftUI
import UIKit

/// Add/edit a modern complication. This screen is only the source flow — name, entity or template —
/// with the live preview on top; everything that shapes how the complication renders lives in
/// `WatchComplicationConfigurationSheet`, opened from the Customize row once the source is set. The
/// flow logic and save side effects live in `WatchComplicationBuilderEditViewModel`; this view keeps
/// only presentation state and the bindings into the view model's config.
struct WatchComplicationBuilderEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WatchComplicationBuilderEditViewModel
    @State private var showEntityPicker = false
    @State private var showConfiguration = false
    /// Whether the inline preview row is on screen. Form recycles offscreen rows, so the row's
    /// appear/disappear tracks scrolling; while it's away the preview floats over the form instead.
    @State private var isInlinePreviewVisible = true
    /// The name field's focus — the only keyboard on this screen, dropped when a source is picked.
    @FocusState private var isNameFocused: Bool

    init(existing: WatchComplicationConfig?) {
        _viewModel = StateObject(wrappedValue: WatchComplicationBuilderEditViewModel(existing: existing))
    }

    /// Server selection. Animated: picking a server reveals the next step of the flow.
    private var serverBinding: Binding<String> {
        Binding(
            get: { viewModel.config.serverId },
            set: { newValue in withAnimation { viewModel.selectServer(newValue) } }
        )
    }

    var body: some View {
        Form {
            previewSection
            nameSection
            sourceSection
            serverSection
            entitySection
            templateSection
            configurationSection
        }
        // Once the inline preview scrolls away, it re-appears as a floating mini preview — only the
        // selected size, zoomed to fit a small watch screen — that the user can drag to any corner
        // and tap (or pinch) to resize, so the live preview stays visible while the flow scrolls.
        .overlay { floatingPreview }
        .navigationTitle(Text(
            viewModel.isNew ? L10n.Watch.Complications.Builder.newTitle : L10n.Watch.Complications.Builder
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
                    Button(role: .confirm) { save() }.disabled(!viewModel.isValid)
                } else {
                    Button { save() } label: { Image(systemSymbol: .checkmark) }
                        .disabled(!viewModel.isValid)
                }
            }
        }
        .onChange(of: viewModel.selectedEntity?.id) { _ in
            // Dismiss the picker sheet once a choice is made.
            showEntityPicker = false
            viewModel.applySelectedEntity()
        }
        .onAppear {
            viewModel.hydrateSelectedEntity()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var previewSection: some View {
        if let server = viewModel.server {
            Section {
                AllFamiliesComplicationPreview(
                    config: viewModel.config,
                    server: server,
                    selectedFamily: viewModel.config.widgetFamily,
                    onUnit: { viewModel.entityUnit = $0 },
                    onAttributes: { viewModel.entityAttributeKeys = $0 },
                    onValueIsNumeric: { viewModel.valueIsNumeric = $0 }
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
            }
        }
    }

    /// The complication's name sits above everything else: it labels the complication in the iOS list
    /// and the watch gallery regardless of the source — it never renders on the face (the `{name}`
    /// token resolves to the entity name or the rendered display-name template; see
    /// `WatchComplicationConfig.faceName`). A blank name falls back to the entity name (shown as the
    /// placeholder); template complications auto-generate one on save.
    private var nameSection: some View {
        Section {
            TextField(text: stringBinding(\.name)) {
                Text(verbatim: viewModel.namePlaceholder)
            }
            .focused($isNameFocused)
        } header: {
            Text(L10n.Watch.Complications.Builder.complicationName)
        }
    }

    /// Step 1: pick the source. Two radio-style cards side by side; the choice drives which of the
    /// sections below reveal themselves, so the form reads as a step-by-step flow.
    private var sourceSection: some View {
        Section {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.oneAndHalf) {
                sourceOptionButton(
                    kind: .entity,
                    title: L10n.Watch.Complications.Builder.sourceEntity,
                    subtitle: L10n.Watch.Complications.Builder.sourceEntitySubtitle
                )
                sourceOptionButton(
                    kind: .customTemplate,
                    title: L10n.Watch.Complications.Builder.sourceTemplate,
                    subtitle: L10n.Watch.Complications.Builder.sourceTemplateSubtitle
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text(L10n.Watch.Complications.Builder.source)
        }
    }

    /// Step 2: the server — template flow only, since templates render against a server but have no
    /// entity picker. The entity flow needs no separate picker: the entity picker carries its own
    /// server filter, and the picked entity decides the server. The first server is pre-selected in
    /// the view model, and with a single server the picker is omitted entirely.
    @ViewBuilder
    private var serverSection: some View {
        if viewModel.selectedSource == .customTemplate, viewModel.servers.count > 1 {
            Section {
                Picker(selection: serverBinding) {
                    ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                        Text(verbatim: server.info.name).tag(server.identifier.rawValue)
                    }
                } label: {
                    Text(L10n.AppIntents.Server.title)
                }
            }
        }
    }

    /// Step 3 (entity): pick the entity — the last step of the source flow, after which the Customize
    /// row opens the configuration sheet.
    @ViewBuilder
    private var entitySection: some View {
        if viewModel.selectedSource == .entity, !viewModel.config.serverId.isEmpty {
            Section {
                // Entity + its context as one row (name primary, context as subtitle); opens the
                // full picker in a sheet.
                Button {
                    presentationHaptic()
                    showEntityPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(verbatim: viewModel.selectedEntity?.name ?? L10n.EntityPicker.placeholder)
                                .foregroundColor(.accentColor)
                            if let entitySubtitle = viewModel.entitySubtitle {
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
                .sheet(isPresented: $showEntityPicker) {
                    NavigationView {
                        EntityPicker(
                            selectedServerId: viewModel.config.serverId,
                            selectedEntity: $viewModel.selectedEntity,
                            domainFilter: nil,
                            mode: .list
                        )
                    }
                    .navigationViewStyle(.stack)
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    /// Step 3 (template): enter the templates — the source of a template complication, and the last
    /// step of the flow. The text template stands in for the display name, showing its rendered
    /// result (or the template source) and opening the full editor in a sheet; the value template
    /// feeds the gauge. The complication name lives in the shared section above, so a blank name
    /// auto-generates "Complication-N" on save.
    @ViewBuilder
    private var templateSection: some View {
        if viewModel.selectedSource == .customTemplate, !viewModel.config.serverId.isEmpty,
           let server = viewModel.server {
            Section {
                JinjaTemplateButton(
                    server: server,
                    title: L10n.Watch.Complications.Builder.displayName,
                    text: templateBinding(\.customTextTemplate),
                    placeholder: "{{ states('sensor.x') }}"
                )
            } header: {
                Text(L10n.Watch.Complications.Builder.displayName)
            }

            Section {
                JinjaTemplateButton(
                    server: server,
                    title: L10n.Watch.Complications.Builder.valueTemplate,
                    text: templateBinding(\.customGaugeTemplate),
                    placeholder: "{{ … }} → 0–1"
                )
            } header: {
                Text(L10n.Watch.Complications.Builder.valueTemplate)
            } footer: {
                Text(L10n.Watch.Complications.Builder.valueTemplateFooter)
            }
        }
    }

    /// Step 4: once the source is fully configured (an entity picked, or a template entered), the way
    /// the complication renders — size, value formatting and each on-face element — is configured in
    /// a sheet, so this screen stays the short source flow.
    @ViewBuilder
    private var configurationSection: some View {
        if viewModel.isSourceConfigured {
            Section {
                Button {
                    presentationHaptic()
                    showConfiguration = true
                } label: {
                    Text(L10n.Watch.Complications.Builder.customize)
                }
                .buttonStyle(.primaryQuietButton)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .sheet(isPresented: $showConfiguration) {
                    WatchComplicationConfigurationSheet(viewModel: viewModel)
                }
            }
        }
    }

    @ViewBuilder
    private var floatingPreview: some View {
        if let server = viewModel.server, !isInlinePreviewVisible {
            FloatingPanel(
                initialCorner: .bottomTrailing,
                initialScale: 1,
                minScale: 0.55,
                // Concentric with the fake watch bezel: its radius plus the panel's content padding.
                cornerRadius: AllFamiliesComplicationPreview.compactBezelCornerRadius + DesignSystem.Spaces.one
            ) {
                AllFamiliesComplicationPreview(
                    config: viewModel.config,
                    server: server,
                    selectedFamily: viewModel.config.widgetFamily,
                    showsOnlySelectedFamily: true,
                    onUnit: { viewModel.entityUnit = $0 },
                    onAttributes: { viewModel.entityAttributeKeys = $0 },
                    onValueIsNumeric: { viewModel.valueIsNumeric = $0 }
                )
            }
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    // MARK: - Rows

    /// The source cards' shape. On iOS 26 the list clips its rows to the section's concentric
    /// container shape, so a fixed-radius card gets its outer corners re-rounded by the clip while a
    /// fixed-radius border does not — the two diverge. A `ConcentricRectangle` matches that clip on
    /// the outer corners (with a fixed minimum for the inner ones), keeping fill and border in sync.
    private var sourceCardShape: AnyShape {
        if #available(iOS 26.0, *) {
            AnyShape(ConcentricRectangle(
                corners: .concentric(minimum: .fixed(DesignSystem.CornerRadius.oneAndHalf)),
                isUniform: true
            ))
        } else {
            AnyShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
        }
    }

    /// One of the two radio-style source cards ("Entity" / "Template"). Selecting a source reveals
    /// the steps that follow it; only one card can be selected at a time.
    private func sourceOptionButton(
        kind: WatchComplicationConfig.Kind,
        title: String,
        subtitle: String
    ) -> some View {
        let isSelected = viewModel.selectedSource == kind
        return Button {
            // Picking a source reveals the steps below it, which the name field's keyboard would
            // cover — so drop its focus on the way.
            isNameFocused = false
            withAnimation { viewModel.selectSource(kind) }
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                HStack(spacing: DesignSystem.Spaces.one) {
                    Image(systemSymbol: isSelected ? .checkmarkCircleFill : .circle)
                        .foregroundStyle(isSelected ? Color.haPrimary : Color.secondary)
                    Text(verbatim: title)
                        .font(DesignSystem.Font.headline)
                        .foregroundStyle(.primary)
                }
                Text(verbatim: subtitle)
                    .font(DesignSystem.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spaces.two)
            .background(
                sourceCardShape.fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                // `AnyShape` has no `strokeBorder`, so draw a double-width centered stroke and clip
                // away the outer half — same result as an inside 2pt border.
                sourceCardShape
                    .stroke(isSelected ? Color.haPrimary : Color.clear, lineWidth: 4)
                    .clipShape(sourceCardShape)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Bindings

    private func save() {
        viewModel.save()
        dismiss()
    }

    /// A light tap for the rows that open a sheet (entity picker, Customize), so the transition out of
    /// the flow is felt as well as seen.
    private func presentationHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func stringBinding(_ keyPath: WritableKeyPath<WatchComplicationConfig, String?>) -> Binding<String> {
        Binding(
            get: { viewModel.config[keyPath: keyPath] ?? "" },
            set: { viewModel.config[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func templateBinding(_ keyPath: WritableKeyPath<WatchComplicationConfig, String?>) -> Binding<String> {
        stringBinding(keyPath).straightQuoted()
    }
}

extension Binding where Value == String {
    /// Normalizes iOS smart punctuation (“ ” ‘ ’) to the straight quotes Jinja expects — the keyboard
    /// substitutes them while typing, silently breaking the template.
    func straightQuoted() -> Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                wrappedValue = newValue
                    .replacingOccurrences(of: "\u{201C}", with: "\"")
                    .replacingOccurrences(of: "\u{201D}", with: "\"")
                    .replacingOccurrences(of: "\u{2018}", with: "'")
                    .replacingOccurrences(of: "\u{2019}", with: "'")
            }
        )
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

#Preview("Editing existing entity complication") {
    // The fully-revealed flow: source selected and entity configured, so the Customize row is visible.
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
    return NavigationView {
        WatchComplicationBuilderEditView(existing: WatchComplicationConfig(
            serverId: serverId,
            widgetFamily: .rectangular,
            entityId: "sensor.battery",
            entityDisplayName: "Battery",
            iconName: "mdi:battery",
            gaugeMin: 0,
            gaugeMax: 100
        ))
    }
}

#Preview("Editing existing template complication") {
    // The template flow: the display-name template stands in for the source.
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
    return NavigationView {
        WatchComplicationBuilderEditView(existing: WatchComplicationConfig(
            serverId: serverId,
            kind: .customTemplate,
            name: "Solar",
            iconName: "mdi:solar-power",
            iconColor: "#FFD60AFF",
            customTextTemplate: "{{ states('sensor.solar_power') }}",
            customGaugeTemplate: "{{ states('sensor.solar_fraction') }}",
            customTextColorTemplate: "{{ '#FF9500' }}",
            isCustomized: true
        ))
    }
}
