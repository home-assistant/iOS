import GRDB
import Shared
import SwiftUI
import UIKit

/// Add/edit a modern complication: pick an entity (auto-designed) or a custom template. The flow
/// logic and save side effects live in `WatchComplicationBuilderEditViewModel`; this view keeps only
/// presentation state and the bindings into the view model's config.
struct WatchComplicationBuilderEditView: View {
    /// The template-editing fields that get the evaluation callout while focused.
    fileprivate enum TemplateField: Hashable {
        case text, gauge, gaugeColor, iconColor, textColor
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WatchComplicationBuilderEditViewModel
    @State private var showEntityPicker = false
    /// Whether the inline preview row is on screen. Form recycles offscreen rows, so the row's
    /// appear/disappear tracks scrolling; while it's away the preview floats over the form instead.
    @State private var isInlinePreviewVisible = true
    /// The template field being edited — the evaluation callout floats over it.
    @FocusState private var focusedTemplateField: TemplateField?
    /// Global-space frames of the on-screen template fields, tracked via `onGeometryChange` (not
    /// anchors/GeometryReader preferences — Form rows live in separate hosting views, where those
    /// resolve stale or wrong coordinates). The callout overlay converts these back to local space.
    @State private var templateFieldFrames: [TemplateField: CGRect] = [:]
    /// Preview-only escape hatch: pretends this field is focused so the callout renders in a
    /// static preview (a real focus can't be established there).
    private let initialTemplateFocus: TemplateField?

    init(existing: WatchComplicationConfig?) {
        self.init(existing: existing, initialTemplateFocus: nil)
    }

    fileprivate init(existing: WatchComplicationConfig?, initialTemplateFocus: TemplateField?) {
        _viewModel = StateObject(wrappedValue: WatchComplicationBuilderEditViewModel(existing: existing))
        self.initialTemplateFocus = initialTemplateFocus
    }

    /// The field whose callout is shown: the focused one, or the preview-only override.
    private var activeTemplateField: TemplateField? {
        focusedTemplateField ?? initialTemplateFocus
    }

    /// Server selection. Animated: picking a server reveals the next step of the flow.
    private var serverBinding: Binding<String> {
        Binding(
            get: { viewModel.config.serverId },
            set: { newValue in withAnimation { viewModel.selectServer(newValue) } }
        )
    }

    /// The size currently selected in the preview — also the size being customized below.
    private var currentFamily: WatchComplicationConfig.Family { viewModel.config.widgetFamily }

    private func updateOptions(_ mutate: (inout WatchComplicationConfig.FamilyOptions) -> Void) {
        var options = viewModel.config.options(for: currentFamily)
        mutate(&options)
        viewModel.config.setOptions(options, for: currentFamily)
    }

    private var showValueBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.showsValue(for: currentFamily) },
            set: { value in updateOptions { $0.showValue = value } }
        )
    }

    private var showNameBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.showsName(for: currentFamily) },
            set: { value in updateOptions { $0.showName = value } }
        )
    }

    private var showIconBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.showsIcon(for: currentFamily) },
            set: { value in updateOptions { $0.showIcon = value } }
        )
    }

    private var showGaugeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.showsGauge(for: currentFamily) },
            set: { value in updateOptions { $0.showGauge = value } }
        )
    }

    private var showMinBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.showsMin(for: currentFamily) },
            set: { value in updateOptions { $0.showMin = value } }
        )
    }

    private var showMaxBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.showsMax(for: currentFamily) },
            set: { value in updateOptions { $0.showMax = value } }
        )
    }

    /// Icon color is global (not per-size); defaults to the Home Assistant primary color.
    private var iconColorBinding: Binding<Color> {
        Binding(
            get: { iconColor },
            set: { viewModel.config.iconColor = UIColor($0).hexString(true) }
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
            get: { viewModel.config.families?[currentFamily.rawValue]?.gaugeMin ?? viewModel.config.gaugeMin },
            set: { value in updateOptions { $0.gaugeMin = value } }
        )
    }

    private var gaugeMaxBinding: Binding<Double?> {
        Binding(
            get: { viewModel.config.families?[currentFamily.rawValue]?.gaugeMax ?? viewModel.config.gaugeMax },
            set: { value in updateOptions { $0.gaugeMax = value } }
        )
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: { viewModel.config.tint(for: currentFamily).map { Color(uiColor: UIColor($0)) } ?? Color.haPrimary },
            set: { value in updateOptions { $0.tint = UIColor(value).hexString(true) } }
        )
    }

    /// The icon's tint, used for the icon picker preview. Defaults to the Home Assistant primary color.
    private var iconColor: Color {
        viewModel.config.iconColor.map { Color(uiColor: UIColor(hex: $0)) } ?? Color.haPrimary
    }

    /// Two-way binding between the stored (possibly server-side "mdi:") icon name and the icon picker.
    private var iconBinding: Binding<MaterialDesignIcons?> {
        Binding(
            get: { viewModel.config.iconName.map { MaterialDesignIcons(serversideValueNamed: $0) } },
            set: { viewModel.config.iconName = $0?.name }
        )
    }

    /// Value source: empty string == the entity state, otherwise an attribute name. Global (the value
    /// text is shared across sizes).
    private var valueAttributeBinding: Binding<String> {
        Binding(
            get: { viewModel.config.valueAttribute ?? "" },
            set: { viewModel.config.valueAttribute = $0.isEmpty ? nil : $0 }
        )
    }

    /// Decimal precision override: `-1` (the picker's "Automatic") maps to nil, meaning follow Home
    /// Assistant's display precision.
    private var valuePrecisionBinding: Binding<Int> {
        Binding(
            get: { viewModel.config.valuePrecision ?? -1 },
            set: { viewModel.config.valuePrecision = $0 < 0 ? nil : $0 }
        )
    }

    /// Unit visibility is global (the value text is shared across sizes).
    private var showUnitBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.showsUnit() },
            set: { viewModel.config.showUnit = $0 }
        )
    }

    private var gaugeStyleBinding: Binding<WatchComplicationConfig.GaugeStyle> {
        Binding(
            get: { viewModel.config.gaugeStyle(for: currentFamily) },
            set: { value in updateOptions { $0.gaugeStyle = value.rawValue } }
        )
    }

    /// Text/value color; defaults to primary when unset.
    private var textColorBinding: Binding<Color> {
        Binding(
            get: { viewModel.config.textColor(for: currentFamily)
                .map { Color(uiColor: UIColor(hex: $0)) } ?? .primary
            },
            set: { value in updateOptions { $0.textColor = UIColor(value).hexString(true) } }
        )
    }

    var body: some View {
        Form {
            if let server = viewModel.server {
                Section {
                    AllFamiliesComplicationPreview(
                        config: viewModel.config,
                        server: server,
                        selectedFamily: viewModel.config.widgetFamily,
                        onUnit: { viewModel.entityUnit = $0 },
                        onAttributes: { viewModel.entityAttributeKeys = $0 },
                        onValueIsNumeric: { viewModel.valueIsNumeric = $0 },
                        onTemplateOutputs: { viewModel.templateOutputs = $0 }
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

            // Step 1: pick the source. Two radio-style cards side by side; the choice drives which of
            // the sections below reveal themselves, so the form reads as a step-by-step flow.
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

            // Step 2: the server. The first one is pre-selected in the view model, and with a single
            // server the picker is omitted entirely — the flow skips straight to the entity/template
            // step.
            if viewModel.selectedSource != nil, viewModel.servers.count > 1 {
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

            // Step 3 (entity): pick the entity, then its value options reveal below.
            if viewModel.selectedSource == .entity, !viewModel.config.serverId.isEmpty {
                Section {
                    // Entity + its context as one row (name primary, context as subtitle); opens the
                    // full picker in a sheet.
                    Button {
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
                    }

                    // Choose whether the value shown is the entity's state or one of its attributes.
                    if viewModel.config.entityId != nil, !viewModel.entityAttributeKeys.isEmpty {
                        Picker(selection: valueAttributeBinding) {
                            Text(L10n.Watch.Complications.Builder.valueSourceState).tag("")
                            ForEach(viewModel.entityAttributeKeys, id: \.self) { key in
                                Text(verbatim: key).tag(key)
                            }
                        } label: {
                            Text(L10n.Watch.Complications.Builder.valueSource)
                        }
                    }

                    // Decimal precision for a numeric value. A picker (not free text) so there is nothing
                    // to validate; "Automatic" follows Home Assistant, and the initial selection is seeded
                    // with Home Assistant's current precision when the entity is chosen.
                    if viewModel.config.entityId != nil {
                        // Decimals only make sense for a numeric value; hidden for string states
                        // (e.g. "home", "on").
                        if viewModel.valueIsNumeric {
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
                        // it blank keeps following Home Assistant. Only offered when the entity actually
                        // reports a unit (or an override was saved earlier, so it can still be cleared).
                        if viewModel.entityUnit != nil || !(viewModel.config.unitOverride ?? "").isEmpty {
                            HStack {
                                Text(L10n.Watch.Complications.Builder.unit)
                                Spacer()
                                TextField(text: stringBinding(\.unitOverride)) {
                                    Text(
                                        verbatim: viewModel.entityUnit
                                            ?? L10n.Watch.Complications.Builder.unitAutomatic
                                    )
                                }
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                            }
                        }
                    }
                }
            }

            // Step 3 (template): enter the templates, then the shared options reveal below. The text
            // template stands in for the display name — same icon + field row as the entity flow —
            // but the field edits the template that renders the complication's text.
            if viewModel.selectedSource == .customTemplate, !viewModel.config.serverId.isEmpty {
                Section {
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                        IconPicker(
                            selectedIcon: iconBinding,
                            selectedColor: iconColorBinding
                        )
                        TextField(text: templateBinding(\.customTextTemplate), axis: .vertical) {
                            Text(verbatim: "{{ states('sensor.x') }}")
                        }
                        .lineLimit(1 ... 6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedTemplateField, equals: .text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(templateFieldFrameReader(.text))
                } header: {
                    Text(L10n.Watch.Complications.Builder.displayName)
                }

                Section {
                    TextField(text: templateBinding(\.customGaugeTemplate), axis: .vertical) {
                        Text(verbatim: "{{ … }} → 0–1")
                    }
                    .lineLimit(1 ... 6)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedTemplateField, equals: .gauge)
                    .background(templateFieldFrameReader(.gauge))
                } header: {
                    Text(L10n.Watch.Complications.Builder.gaugeTemplate)
                }
            }

            // Step 4: once the source is fully configured (an entity picked, or a template entered),
            // the display options reveal: name/icon (entity flow — the template flow's display-name
            // row above edits the text template instead), then the Customize disclosure.
            if viewModel.isSourceConfigured {
                if viewModel.config.kind == .entity {
                    Section {
                        // Icon + name on one row, matching MagicItemCustomizationView. The icon is
                        // auto-derived from the entity and can be overridden here; a blank name falls
                        // back to the entity name.
                        HStack(spacing: DesignSystem.Spaces.two) {
                            IconPicker(
                                selectedIcon: iconBinding,
                                selectedColor: iconColorBinding
                            )
                            TextField(text: stringBinding(\.name)) {
                                Text(verbatim: viewModel.namePlaceholder)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } header: {
                        Text(L10n.Watch.Complications.Builder.displayName)
                    }
                }

                // Progressive disclosure: keep the initial screen simple (name + source). Everything
                // below is opt-in behind "Customize", so the average user isn't faced with a crowded
                // form.
                Section {
                    Toggle(isOn: $viewModel.isCustomizing.animation()) {
                        Text(L10n.Watch.Complications.Builder.customize)
                    }
                } footer: {
                    Text(L10n.Watch.Complications.Builder.customizeFooter)
                }
            }

            if viewModel.isSourceConfigured, viewModel.isCustomizing {
                // Per-size display options, bound to the size selected in the preview above.
                Section {
                    Toggle(isOn: showNameBinding) { Text(L10n.Watch.Complications.Builder.showName) }
                    Toggle(isOn: showValueBinding) { Text(L10n.Watch.Complications.Builder.showValue) }
                    // Inline has no icon.
                    if currentFamily != .inline {
                        Toggle(isOn: showIconBinding) { Text(L10n.Watch.Complications.Builder.showIcon) }
                    }
                    if viewModel.config.kind == .entity,
                       viewModel.entityUnit != nil || !(viewModel.config.unitOverride ?? "").isEmpty {
                        Toggle(isOn: showUnitBinding) { Text(L10n.Watch.Complications.Builder.showUnit) }
                    }

                    if familyHasProgressBar {
                        Toggle(isOn: showGaugeBinding) { Text(verbatim: gaugeToggleTitle) }
                        if viewModel.config.showsGauge(for: currentFamily) {
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
                            if viewModel.config.kind == .entity {
                                numberField(title: L10n.Watch.Complications.Builder.minimum, value: gaugeMinBinding)
                                numberField(title: L10n.Watch.Complications.Builder.maximum, value: gaugeMaxBinding)
                                if viewModel.config.gaugeRange(for: currentFamily) != nil {
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
                    // Family switcher: selects the size being customized, which is also the size the
                    // floating mini preview shows.
                    Picker(selection: $viewModel.config.widgetFamily) {
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
                        Toggle(isOn: $viewModel.useCustomColors.animation()) {
                            Text(L10n.Watch.Complications.Builder.customColors)
                        }
                        if viewModel.useCustomColors {
                            // Template complications can source each color from a template instead
                            // of the static pickers; the pickers stay visible but read as disabled,
                            // and each gets its own template field below it.
                            if viewModel.config.kind == .customTemplate {
                                Toggle(isOn: $viewModel.useTemplateColor.animation()) {
                                    Text(L10n.Watch.Complications.Builder.colorFromTemplate)
                                }
                            }
                            if familyHasProgressBar, viewModel.config.showsGauge(for: currentFamily) {
                                staticColorPicker(gaugeColorTitle, selection: tintBinding)
                                if viewModel.useTemplateColor {
                                    colorTemplateField(.gaugeColor, keyPath: \.customGaugeColorTemplate)
                                }
                            }
                            if viewModel.config.showsIcon(for: currentFamily) {
                                staticColorPicker(
                                    L10n.Watch.Complications.Builder.iconColor,
                                    selection: iconColorBinding
                                )
                                if viewModel.useTemplateColor {
                                    colorTemplateField(.iconColor, keyPath: \.customIconColorTemplate)
                                }
                            }
                            staticColorPicker(
                                L10n.Watch.Complications.Builder.textColor,
                                selection: textColorBinding
                            )
                            if viewModel.useTemplateColor {
                                colorTemplateField(.textColor, keyPath: \.customTextColorTemplate)
                            }
                        }
                    } header: {
                        Text(L10n.Watch.Complications.Builder.colors)
                    }
                }
            } // end if isSourceConfigured, isCustomizing
        }
        // Once the inline preview scrolls away, it re-appears as a floating mini preview — only the
        // selected size, zoomed to fit a small watch screen — that the user can drag to any corner
        // and tap (or pinch) to resize, so the live preview stays visible while editing options
        // further down the form.
        .overlay {
            if let server = viewModel.server, !isInlinePreviewVisible {
                FloatingPanel(
                    initialCorner: .topTrailing,
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
                        onValueIsNumeric: { viewModel.valueIsNumeric = $0 },
                        onTemplateOutputs: { viewModel.templateOutputs = $0 }
                    )
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        // While a template field is being edited, a popover-style callout floats over it with the
        // live evaluation: a spinner while loading, the rendered result, the error on failure, and
        // the resulting color for the color templates. Drawn as a form-level overlay (not a real
        // popover presentation) so it never steals focus from the keyboard while typing, and never
        // gets clipped by the section shape.
        .overlay {
            GeometryReader { proxy in
                if let field = activeTemplateField,
                   let globalRect = templateFieldFrames[field],
                   let output = calloutOutput(for: field) {
                    let origin = proxy.frame(in: .global).origin
                    let rect = globalRect.offsetBy(dx: -origin.x, dy: -origin.y)
                    templateCallout(for: field, output: output)
                        .alignmentGuide(.leading) { dimensions in
                            // Centered over the field, clamped so the bubble stays on screen.
                            let halfWidth = dimensions.width / 2
                            let centerX = min(
                                max(rect.midX, halfWidth + DesignSystem.Spaces.two),
                                proxy.size.width - halfWidth - DesignSystem.Spaces.two
                            )
                            return halfWidth - centerX
                        }
                        .alignmentGuide(.top) { dimensions in
                            // Bottom edge (including the arrow) clearly above the field's top.
                            dimensions.height - (rect.minY - DesignSystem.Spaces.two)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .allowsHitTesting(false)
            .animation(.default, value: viewModel.templateOutputs)
        }
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

    private func save() {
        viewModel.save()
        dismiss()
    }

    private func stringBinding(_ keyPath: WritableKeyPath<WatchComplicationConfig, String?>) -> Binding<String> {
        Binding(
            get: { viewModel.config[keyPath: keyPath] ?? "" },
            set: { viewModel.config[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    /// Like `stringBinding`, but normalizes iOS smart punctuation (“ ” ‘ ’) to the straight quotes
    /// Jinja expects — the keyboard substitutes them while typing, silently breaking the template.
    private func templateBinding(_ keyPath: WritableKeyPath<WatchComplicationConfig, String?>) -> Binding<String> {
        Binding(
            get: { viewModel.config[keyPath: keyPath] ?? "" },
            set: { newValue in
                let sanitized = newValue
                    .replacingOccurrences(of: "\u{201C}", with: "\"")
                    .replacingOccurrences(of: "\u{201D}", with: "\"")
                    .replacingOccurrences(of: "\u{2018}", with: "'")
                    .replacingOccurrences(of: "\u{2019}", with: "'")
                viewModel.config[keyPath: keyPath] = sanitized.isEmpty ? nil : sanitized
            }
        )
    }

    /// A static color picker that reads as disabled while template colors drive the complication.
    private func staticColorPicker(_ title: String, selection: Binding<Color>) -> some View {
        ColorPicker(title, selection: selection, supportsOpacity: false)
            .disabled(viewModel.useTemplateColor)
            .opacity(viewModel.useTemplateColor ? 0.4 : 1)
    }

    /// A color template field: renders a hex string that overrides the static picker above it. The
    /// trailing swatch previews the evaluated color once the debounced render succeeds.
    private func colorTemplateField(
        _ field: TemplateField,
        keyPath: WritableKeyPath<WatchComplicationConfig, String?>
    ) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
            TextField(text: templateBinding(keyPath), axis: .vertical) {
                Text(verbatim: "{{ … }} → #RRGGBB")
            }
            .lineLimit(1 ... 6)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($focusedTemplateField, equals: field)
            if let hex = WatchComplicationBuilderEditViewModel.evaluatedHex(from: templateOutput(for: field)) {
                Circle()
                    .fill(Color(uiColor: UIColor(hex: hex)))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
            }
        }
        .background(templateFieldFrameReader(field))
    }

    /// Tracks a template field's global frame for the callout overlay.
    private func templateFieldFrameReader(_ field: TemplateField) -> some View {
        Color.clear
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newValue in
                templateFieldFrames[field] = newValue
            }
    }

    private func templateOutput(for field: TemplateField) -> TemplateRenderer.Output {
        switch field {
        case .text: return viewModel.templateOutputs.text
        case .gauge: return viewModel.templateOutputs.gauge
        case .gaugeColor: return viewModel.templateOutputs.gaugeColor
        case .iconColor: return viewModel.templateOutputs.iconColor
        case .textColor: return viewModel.templateOutputs.textColor
        }
    }

    /// The output the callout should show for a field, or nil to hide it (nothing evaluated yet, or
    /// the template is empty).
    private func calloutOutput(for field: TemplateField) -> TemplateRenderer.Output? {
        let output = templateOutput(for: field)
        switch output {
        case .idle: return nil
        case let .success(value) where value.isEmpty: return nil
        default: return output
        }
    }

    /// The popover-style bubble floating over the focused template field: loading spinner, rendered
    /// result, error message, or — for the color templates — the resulting color.
    @ViewBuilder
    private func templateCallout(for field: TemplateField, output: TemplateRenderer.Output) -> some View {
        let isColorField = [.gaugeColor, .iconColor, .textColor].contains(field)
        Group {
            switch output {
            case .idle:
                EmptyView()
            case .loading:
                HStack(spacing: DesignSystem.Spaces.one) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.Watch.Complications.Builder.templateEvaluating)
                        .foregroundStyle(.secondary)
                }
            case let .success(value):
                if isColorField {
                    if let hex = WatchComplicationConfig.normalizedHexColor(from: value) {
                        HStack(spacing: DesignSystem.Spaces.one) {
                            Circle()
                                .fill(Color(uiColor: UIColor(hex: hex)))
                                .frame(width: 16, height: 16)
                                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                            Text(verbatim: hex)
                                .font(.footnote.monospaced())
                        }
                    } else {
                        Text(L10n.Watch.Complications.Builder.templateInvalidHex)
                            .foregroundStyle(Color(.systemRed))
                    }
                } else {
                    Text(verbatim: value)
                        .font(.footnote.monospaced())
                }
            case let .failure(message):
                Text(verbatim: message)
                    .foregroundStyle(Color(.systemRed))
            }
        }
        .font(.footnote)
        .lineLimit(4)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 260, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
        .padding(.vertical, DesignSystem.Spaces.one)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
        )
        // Popover-style arrow pointing at the field below.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(45))
                .offset(y: 5)
        }
    }

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

#Preview("Editing existing entity complication") {
    // The fully-revealed flow: source selected and entity configured, so the value options,
    // display name and Customize sections are all visible.
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
    return NavigationView {
        WatchComplicationBuilderEditView(existing: WatchComplicationConfig(
            serverId: serverId,
            entityId: "sensor.battery",
            entityDisplayName: "Battery",
            iconName: "mdi:battery",
            gaugeMin: 0,
            gaugeMax: 100
        ))
    }
}

#Preview("Editing existing template complication") {
    // The template flow: one titled section per template field, and template colors under Colors.
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

#Preview("Template evaluation callout") {
    // The popover-style callout over the template field being edited (focus is simulated — a real
    // first responder can't be established in a static preview).
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
    return NavigationView {
        WatchComplicationBuilderEditView(
            existing: WatchComplicationConfig(
                serverId: serverId,
                kind: .customTemplate,
                name: "Solar",
                customTextTemplate: "{{ states('sensor.solar_power') }}"
            ),
            initialTemplateFocus: .text
        )
    }
}
