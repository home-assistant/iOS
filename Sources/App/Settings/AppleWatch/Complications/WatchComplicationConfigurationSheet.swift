import CoreTransferable
import Shared
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The complication builder's configuration step: everything that shapes how the complication
/// renders, once its source (entity or template) is picked. Presented as a medium/large sheet over
/// `WatchComplicationBuilderEditView`, which keeps the source flow — and its inline preview — behind
/// it: at the medium detent that preview is still visible above the sheet, so the floating mini
/// preview only shows up once the sheet is dragged to full height.
struct WatchComplicationConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WatchComplicationBuilderEditViewModel
    /// The detent the sheet currently rests at — drives the floating preview (see `floatingPreview`).
    @State private var detent: PresentationDetent = .medium

    /// The size currently selected in the family switcher — also the size being customized below.
    private var currentFamily: WatchComplicationConfig.Family { viewModel.config.widgetFamily }

    var body: some View {
        NavigationView {
            Form {
                entityValueSection
                familySection
                slotSections
            }
            // Floats over the form only — never over the navigation bar, so the Done button stays
            // reachable.
            .overlay {
                floatingPreview
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: detent)
            }
            .navigationTitle(Text(L10n.Watch.Complications.Builder.customize))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) { dismiss() }
                    } else {
                        Button { dismiss() } label: { Image(systemSymbol: .checkmark) }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    /// The mini preview — only the selected size, zoomed to fit a small watch screen — draggable to
    /// any corner and tappable (or pinchable) to resize. Shown at the large detent only: at medium
    /// the builder's own inline preview is still on screen above the sheet, so a second one would
    /// just be noise.
    @ViewBuilder
    private var floatingPreview: some View {
        if detent == .large, let server = viewModel.server {
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
                    selectedFamily: currentFamily,
                    showsOnlySelectedFamily: true,
                    onUnit: { viewModel.entityUnit = $0 },
                    onAttributes: { viewModel.entityAttributeKeys = $0 },
                    onValueIsNumeric: { viewModel.valueIsNumeric = $0 }
                )
            }
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    // MARK: - Sections

    /// The value's data and formatting for entity complications — global, shared by every size: which
    /// attribute (or the state) feeds the value, its decimals and its unit. Template complications
    /// source their value on the main screen instead, next to the display-name template.
    ///
    /// Every row here is conditional (attributes, numeric values and units are all optional), so the
    /// section itself is gated too — otherwise it would render as an empty gap.
    @ViewBuilder
    private var entityValueSection: some View {
        if viewModel.config.entityId != nil, hasValueOptions {
            Section {
                // Choose whether the value shown is the entity's state or one of its attributes.
                if !viewModel.entityAttributeKeys.isEmpty {
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
                // with Home Assistant's current precision when the entity is chosen. Decimals only
                // make sense for a numeric value; hidden for string states (e.g. "home", "on").
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

                // Optional custom unit; the placeholder shows the auto-resolved unit, so leaving it
                // blank keeps following Home Assistant. Only offered when the entity actually reports
                // a unit (or an override was saved earlier, so it can still be cleared).
                if hasUnit {
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
                    Toggle(isOn: showUnitBinding) { Text(L10n.Watch.Complications.Builder.showUnit) }
                }
            }
        }
    }

    /// Family switcher: selects the size the sections below configure — also the size the floating
    /// mini preview shows.
    private var familySection: some View {
        Section {
            Picker(selection: $viewModel.config.widgetFamily) {
                ForEach(WatchComplicationConfig.Family.allCases) { family in
                    Text(verbatim: family.title).tag(family)
                }
            } label: { EmptyView() }
                .pickerStyle(.segmented)
        } footer: {
            Text(L10n.Watch.Complications.Builder.sizeOptionsFooter)
        }
    }

    /// One section per UI slot of the selected size: visibility, content formula, and — for the value
    /// slot — the gauge and color options that shape how that element renders. Each section is
    /// self-contained (one on-face element).
    private var slotSections: some View {
        ForEach(ComplicationSlot.slots(for: currentFamily)) { slot in
            Section {
                ComplicationSlotRow(
                    config: $viewModel.config,
                    slot: slot,
                    server: viewModel.server,
                    attributeKeys: viewModel.config.kind == .entity ? viewModel.entityAttributeKeys : []
                )
                // The icon's glyph + color live with the icon element; shown once it's visible.
                if slot == .icon, viewModel.config.isSlotVisible(.icon, for: currentFamily) {
                    iconSlotOptions
                }
                if slot == .value {
                    valueSlotOptions
                }
                // Bottom text can override the shared text color with its own.
                if slot == .bottomText, viewModel.config.isSlotVisible(.bottomText, for: currentFamily) {
                    ColorPicker(
                        L10n.Watch.Complications.Builder.color,
                        selection: bottomTextColorBinding,
                        supportsOpacity: false
                    )
                }
            } header: {
                Text(verbatim: slot.editorTitle)
            }
        }
    }

    /// Gauge + color options shown inside the value slot's section: everything else that shapes how
    /// the value element renders (the gauge/progress bar with its range and min/max labels, and the
    /// complication's colors). Keeping these with the value keeps each section self-contained, one
    /// per on-face element.
    @ViewBuilder
    private var valueSlotOptions: some View {
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
        appearanceOptions
    }

    /// The complication's colors, shown inline with the value element (its own icon color lives with
    /// the icon in the icon section). Always visible — no opt-in — so the colors are discoverable
    /// without hunting for a toggle. The gauge/progress color only applies when a gauge is shown; the
    /// text color governs every text slot (title / subtitle / value / bottom text).
    @ViewBuilder
    private var appearanceOptions: some View {
        // Template complications can source each color from a template instead of the static pickers;
        // the toggle swaps each picker for a template field below it.
        if viewModel.config.kind == .customTemplate {
            Toggle(isOn: $viewModel.useTemplateColor.animation()) {
                Text(L10n.Watch.Complications.Builder.colorFromTemplate)
            }
        }
        if familyHasProgressBar, viewModel.config.showsGauge(for: currentFamily) {
            staticColorPicker(gaugeColorTitle, selection: tintBinding)
            if templateColorsActive {
                colorTemplateField(\.customGaugeColorTemplate, title: gaugeColorTitle)
            }
        }
        staticColorPicker(L10n.Watch.Complications.Builder.textColor, selection: textColorBinding)
        if templateColorsActive {
            colorTemplateField(\.customTextColorTemplate, title: L10n.Watch.Complications.Builder.textColor)
        }
    }

    /// The icon element's glyph + color (global icon config), shown in the Icon section once the icon
    /// is visible. Template complications can also drive the icon color from a template.
    @ViewBuilder
    private var iconSlotOptions: some View {
        IconPicker(
            selectedIcon: iconBinding,
            selectedColor: iconColorBinding,
            style: .row(title: L10n.Watch.Complications.Slot.icon)
        )
        staticColorPicker(L10n.Watch.Complications.Builder.iconColor, selection: iconColorBinding)
        if templateColorsActive {
            colorTemplateField(\.customIconColorTemplate, title: L10n.Watch.Complications.Builder.iconColor)
        }
    }

    // MARK: - Rows

    /// A static color picker that reads as disabled while template colors drive the complication.
    private func staticColorPicker(_ title: String, selection: Binding<Color>) -> some View {
        ColorPicker(title, selection: selection, supportsOpacity: false)
            .disabled(templateColorsActive)
            .opacity(templateColorsActive ? 0.4 : 1)
    }

    /// A color template row: shows the evaluated color (or the template source) and opens the full
    /// template editor in a sheet. The result overrides the static picker above it.
    @ViewBuilder
    private func colorTemplateField(
        _ keyPath: WritableKeyPath<WatchComplicationConfig, String?>,
        title: String
    ) -> some View {
        if let server = viewModel.server {
            JinjaTemplateButton(
                server: server,
                title: title,
                text: templateBinding(keyPath),
                placeholder: "{{ … }} → #RRGGBB",
                expectsColor: true
            )
        }
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

    // MARK: - Titles

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

    /// Whether a unit is available at all: reported by the entity, or an override saved earlier (so it
    /// can still be cleared).
    private var hasUnit: Bool {
        viewModel.entityUnit != nil || !(viewModel.config.unitOverride ?? "").isEmpty
    }

    /// Whether the entity offers anything to format: attributes to pick from, a numeric value to round,
    /// or a unit to show.
    private var hasValueOptions: Bool {
        !viewModel.entityAttributeKeys.isEmpty || viewModel.valueIsNumeric || hasUnit
    }

    /// Whether template colors currently drive the complication. Only the template kind renders
    /// color templates, so this — not `useTemplateColor` alone — gates the template fields and the
    /// static pickers' disabled state: switching the source back to entity re-enables the static
    /// colors even while the template fields keep their content for a later switch back.
    private var templateColorsActive: Bool {
        viewModel.config.kind == .customTemplate && viewModel.useTemplateColor
    }

    // MARK: - Bindings

    private func updateOptions(_ mutate: (inout WatchComplicationConfig.FamilyOptions) -> Void) {
        var options = viewModel.config.options(for: currentFamily)
        mutate(&options)
        viewModel.config.setOptions(options, for: currentFamily)
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

    private var gaugeStyleBinding: Binding<WatchComplicationConfig.GaugeStyle> {
        Binding(
            get: { viewModel.config.gaugeStyle(for: currentFamily) },
            set: { value in updateOptions { $0.gaugeStyle = value.rawValue } }
        )
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: { viewModel.config.tint(for: currentFamily).map { Color(uiColor: UIColor($0)) } ?? Color.haPrimary },
            set: { value in updateOptions { $0.tint = UIColor(value).hexString(true) } }
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

    /// The bottom text's own color: a per-slot override that falls back to the shared text color when
    /// unset, so the picker starts on the effective color.
    private var bottomTextColorBinding: Binding<Color> {
        Binding(
            get: {
                let hex = viewModel.config.slotColor(.bottomText, for: currentFamily)
                    ?? viewModel.config.textColor(for: currentFamily)
                return hex.map { Color(uiColor: UIColor(hex: $0)) } ?? .primary
            },
            set: { value in
                var slot = viewModel.config.slotConfig(.bottomText, for: currentFamily) ?? ComplicationSlotConfig()
                slot.color = UIColor(value).hexString(true)
                viewModel.config.setSlotConfig(slot, slot: .bottomText, for: currentFamily)
            }
        )
    }

    /// Icon color is global (not per-size); defaults to the Home Assistant primary color.
    private var iconColorBinding: Binding<Color> {
        Binding(
            get: { viewModel.config.iconColor.map { Color(uiColor: UIColor(hex: $0)) } ?? Color.haPrimary },
            set: { viewModel.config.iconColor = UIColor($0).hexString(true) }
        )
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

#Preview("Complication configuration") {
    // Previews have no onboarded server; without one, `server` is nil and the preview section is
    // hidden. Seed a fake so the whole sheet (including the complication mock) renders.
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    let serverId = Current.servers.all.first?.identifier.rawValue ?? ""
    // Rectangular has the most slots, so the full element-centric layout is visible: one section per
    // slot, with the value section carrying the gauge and colors inline.
    return WatchComplicationConfigurationSheet(viewModel: WatchComplicationBuilderEditViewModel(
        existing: WatchComplicationConfig(
            serverId: serverId,
            widgetFamily: .rectangular,
            entityId: "sensor.battery",
            entityDisplayName: "Battery",
            iconName: "mdi:battery",
            gaugeMin: 0,
            gaugeMax: 100
        )
    ))
}

// MARK: - ComplicationSlotRow

extension WatchComplicationConfigurationSheet {
    /// One slot of the selected size in the complication builder: a visibility toggle and, for text
    /// slots, the content choice — the slot's default, or a custom formula mixing hardcoded text
    /// with tokens (`{name}`, `{value}`, `{attr:…}`, and `{template}` for template complications).
    /// Entity complications only get on-device tokens: template rendering is an admin-only server
    /// operation. Nested (rather than its own file) so it stays App-target-only without a
    /// project-file change: this folder is synchronized into the Shared targets too, and a
    /// standalone file would need per-file membership exceptions in the pbxproj.
    private struct ComplicationSlotRow: View {
        @Binding var config: WatchComplicationConfig
        let slot: ComplicationSlot
        let server: Server?
        /// Attribute names offered by the Insert menu (entity kind; empty otherwise).
        let attributeKeys: [String]

        private var family: WatchComplicationConfig.Family { config.widgetFamily }

        private var currentSlotConfig: ComplicationSlotConfig {
            config.slotConfig(slot, for: family) ?? ComplicationSlotConfig()
        }

        private func update(_ mutate: (inout ComplicationSlotConfig) -> Void) {
            var updated = currentSlotConfig
            mutate(&updated)
            config.setSlotConfig(updated, slot: slot, for: family)
        }

        private var isVisible: Binding<Bool> {
            Binding(
                get: { config.isSlotVisible(slot, for: family) },
                set: { newValue in update { $0.isVisible = newValue } }
            )
        }

        /// Default vs. custom content: custom == a stored formula. Switching back to default discards
        /// the formula, so the slot follows the built-in behavior again.
        private var isCustomContent: Binding<Bool> {
            Binding(
                get: { currentSlotConfig.formula != nil },
                set: { custom in
                    update { slotConfig in
                        slotConfig.formula = custom ? config.defaultFormula(for: slot, family: family) : nil
                    }
                }
            )
        }

        private var formula: ComplicationFormula {
            currentSlotConfig.formula ?? config.defaultFormula(for: slot, family: family)
        }

        /// The source of the formula's `{template}` token, edited in the full template editor.
        private var templateSource: Binding<String> {
            Binding(
                get: { formula.templates.first ?? "" },
                set: { newValue in
                    let parts: [ComplicationFormula.Part] = formula.parts.map { part in
                        if case .template = part { return .template(newValue) }
                        return part
                    }
                    update { $0.formula = ComplicationFormula(parts: parts) }
                }
            )
        }

        var body: some View {
            Toggle(isOn: isVisible.animation()) { Text(L10n.Watch.Complications.Builder.show) }
            if isVisible.wrappedValue, slot != .icon {
                Picker(selection: isCustomContent.animation()) {
                    Text(L10n.Watch.Complications.Builder.contentDefault).tag(false)
                    Text(L10n.Watch.Complications.Builder.contentCustom).tag(true)
                } label: {
                    Text(L10n.Watch.Complications.Builder.content)
                }
                .pickerStyle(.segmented)
                if isCustomContent.wrappedValue {
                    // The formula is edited as pills, not raw token text: dynamic tokens are tinted
                    // capsules, hardcoded text is typed straight into neutral capsule fields, and each
                    // pill removes with its x. New pieces come from the + menu and land at the end,
                    // from where a pill can be dragged onto another to reorder the formula.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spaces.half) {
                            ForEach(Array(formula.parts.enumerated()), id: \.offset) { index, part in
                                reorderablePartPill(at: index, part: part)
                            }
                            insertMenu
                        }
                        .padding(.vertical, DesignSystem.Spaces.half)
                    }
                    // Only worth saying once there is something to reorder — a single pill has nowhere
                    // to go, and the hint would just be noise in every slot the user customizes.
                    if formula.parts.count > 1 {
                        Text(L10n.Watch.Complications.Builder.reorderTokensHint)
                            .font(DesignSystem.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    if config.kind == .customTemplate, let server, !formula.templates.isEmpty {
                        JinjaTemplateButton(
                            server: server,
                            title: L10n.Watch.Complications.Builder.tokenTemplate,
                            text: templateSource,
                            placeholder: "{{ states('sensor.x') }}"
                        )
                    }
                }
            }
        }

        /// The drag payload for reordering: the dragged pill's position in the formula. A private
        /// `Codable` type carried as JSON, so only a pill from this very list can be dropped onto
        /// another one — text dragged in from elsewhere fails to decode and the drop is refused.
        private struct DraggedFormulaPart: Codable, Transferable {
            let index: Int

            static var transferRepresentation: some TransferRepresentation {
                CodableRepresentation(contentType: .json)
            }
        }

        /// A pill the user can pick up and drop onto another one to reorder the formula. The drag
        /// preview is the pill itself (minus its remove button, which has nothing to act on mid-drag),
        /// and the same move is offered as VoiceOver actions, which cannot perform a drag.
        private func reorderablePartPill(at index: Int, part: ComplicationFormula.Part) -> some View {
            partPill(at: index, part: part)
                .draggable(DraggedFormulaPart(index: index)) {
                    pillLabel(for: part)
                }
                .dropDestination(for: DraggedFormulaPart.self) { items, _ in
                    guard let source = items.first?.index else { return false }
                    return movePart(from: source, to: index)
                }
                .accessibilityAction(named: Text(L10n.Watch.Complications.Builder.moveTokenLeft)) {
                    _ = movePart(from: index, to: index - 1)
                }
                .accessibilityAction(named: Text(L10n.Watch.Complications.Builder.moveTokenRight)) {
                    _ = movePart(from: index, to: index + 1)
                }
        }

        /// Moves a pill to another position, keeping the rest of the formula in order. Returns whether
        /// anything moved, which is also the drop's "was this accepted" answer.
        @discardableResult
        private func movePart(from source: Int, to destination: Int) -> Bool {
            guard source != destination, formula.parts.indices.contains(source),
                  formula.parts.indices.contains(destination) else { return false }
            withAnimation {
                updateParts { parts in
                    parts.insert(parts.remove(at: source), at: destination)
                }
            }
            return true
        }

        /// One formula piece as a pill: text parts are edited in place, dynamic tokens show their
        /// friendly name; every pill carries its own remove button.
        private func partPill(at index: Int, part: ComplicationFormula.Part) -> some View {
            let isText = isTextPart(part)
            return pillChrome(isText: isText) {
                HStack(spacing: DesignSystem.Spaces.half) {
                    if isText {
                        TextField(L10n.Watch.Complications.Builder.tokenText, text: textBinding(at: index))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .fixedSize()
                    } else {
                        Text(verbatim: pillTitle(for: part))
                    }
                    Button {
                        withAnimation { removePart(at: index) }
                    } label: {
                        Image(systemSymbol: .xmarkCircleFill)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Watch.Complications.Builder.removeToken(accessibilityTitle(for: part)))
                }
            }
        }

        /// The pill under the finger while dragging: the same capsule with its title only — the text
        /// field and the remove button have nothing to act on mid-drag.
        private func pillLabel(for part: ComplicationFormula.Part) -> some View {
            pillChrome(isText: isTextPart(part)) {
                Text(verbatim: accessibilityTitle(for: part))
            }
        }

        /// The pill's chrome: the capsule fill and text color that tell a dynamic token apart from
        /// hardcoded text. Shared by the editable pill and the drag preview so the two look alike.
        private func pillChrome(isText: Bool, @ViewBuilder content: () -> some View) -> some View {
            content()
                .font(.callout)
                .padding(.horizontal, DesignSystem.Spaces.one)
                .padding(.vertical, DesignSystem.Spaces.half)
                .foregroundStyle(isText ? Color.primary : Color.haPrimary)
                .background(
                    Capsule().fill(isText ? Color(uiColor: .tertiarySystemFill) : Color.haPrimary.opacity(0.15))
                )
        }

        private func isTextPart(_ part: ComplicationFormula.Part) -> Bool {
            if case .text = part { return true }
            return false
        }

        private func pillTitle(for part: ComplicationFormula.Part) -> String {
            switch part {
            case let .text(text): return text
            case .entityName: return L10n.Watch.Complications.Builder.tokenEntityName
            case .state: return L10n.Watch.Complications.Builder.tokenValue
            case let .attribute(name): return name
            case .template: return L10n.Watch.Complications.Builder.tokenTemplate
            }
        }

        /// VoiceOver name for a pill: same as the visible title, but an as-yet-empty text pill falls
        /// back to the generic "Text" label so the remove button never announces a dangling "Remove".
        private func accessibilityTitle(for part: ComplicationFormula.Part) -> String {
            let title = pillTitle(for: part)
            return title.isEmpty ? L10n.Watch.Complications.Builder.tokenText : title
        }

        private func updateParts(_ mutate: (inout [ComplicationFormula.Part]) -> Void) {
            var parts = formula.parts
            mutate(&parts)
            // Deleting the last pill returns the slot to its default content: rendering ignores empty
            // formulas anyway, so keeping one stored would show "Custom" with an empty pill list while
            // silently rendering the default.
            update { $0.formula = parts.isEmpty ? nil : ComplicationFormula(parts: parts) }
        }

        private func removePart(at index: Int) {
            updateParts { parts in
                guard parts.indices.contains(index) else { return }
                parts.remove(at: index)
            }
        }

        private func appendPart(_ part: ComplicationFormula.Part) {
            withAnimation { updateParts { $0.append(part) } }
        }

        /// In-place editing for a text pill. Index-guarded: SwiftUI can call stale bindings while the
        /// pill list animates a removal.
        private func textBinding(at index: Int) -> Binding<String> {
            Binding(
                get: {
                    guard formula.parts.indices.contains(index),
                          case let .text(text) = formula.parts[index] else { return "" }
                    return text
                },
                set: { newValue in
                    updateParts { parts in
                        guard parts.indices.contains(index) else { return }
                        parts[index] = .text(newValue)
                    }
                }
            )
        }

        /// Appends a piece at the end of the formula. Attributes come from the live preview's reported
        /// keys; the template token is offered once, for template complications only.
        private var insertMenu: some View {
            Menu {
                Button(L10n.Watch.Complications.Builder.tokenText) { appendPart(.text("")) }
                Button(L10n.Watch.Complications.Builder.tokenEntityName) { appendPart(.entityName) }
                Button(L10n.Watch.Complications.Builder.tokenValue) { appendPart(.state) }
                if !attributeKeys.isEmpty {
                    Menu {
                        ForEach(attributeKeys, id: \.self) { key in
                            Button(key) { appendPart(.attribute(key)) }
                        }
                    } label: {
                        Text(L10n.Watch.Complications.Builder.tokenAttributes)
                    }
                }
                if config.kind == .customTemplate, formula.templates.isEmpty {
                    Button(L10n.Watch.Complications.Builder.tokenTemplate) {
                        appendPart(.template(config.customTextTemplate ?? ""))
                    }
                }
            } label: {
                Image(systemSymbol: .plusCircleFill)
            }
            .accessibilityLabel(Text(L10n.Watch.Complications.Builder.insertToken))
        }
    }
}

/// Localized slot names live here (not in HAModels, which has no L10n access).
extension ComplicationSlot {
    var editorTitle: String {
        switch self {
        case .icon: return L10n.Watch.Complications.Slot.icon
        case .title: return L10n.Watch.Complications.Slot.title
        case .subtitle: return L10n.Watch.Complications.Slot.subtitle
        case .value: return L10n.Watch.Complications.Slot.value
        case .bottomText: return L10n.Watch.Complications.Slot.bottomText
        }
    }
}
