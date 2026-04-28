import Shared
import SwiftUI

/// SwiftUI replacement for `ComplicationEditViewController`.
struct ComplicationEditView: View {
    @StateObject private var viewModel: ComplicationEditViewModel
    @Environment(\.dismiss) private var dismiss

    // The editor currently only renders its sections once the server selection
    // is resolved, so we need a single source of truth for the active server
    // passed to the live template renderers below.
    @State private var showDeleteConfirmation = false

    /// Called after a successful save for newly-created complications, used to
    /// dismiss the containing modal sheet in the list view.
    private let onSaved: (() -> Void)?

    init(config: WatchComplication, isNew: Bool, onSaved: (() -> Void)?) {
        self._viewModel = StateObject(wrappedValue: ComplicationEditViewModel(
            config: config,
            isNew: isNew
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            templateSection
            ComplicationEditTextAreas(viewModel: viewModel)
            column2AlignmentSection
            ComplicationEditGaugeSection(viewModel: viewModel)
            ComplicationEditRingSection(viewModel: viewModel)
            iconSection
            if !viewModel.isNew {
                deleteSection
            }
        }
        .navigationTitle(viewModel.family.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.saveLabel) {
                    viewModel.save()
                    if let onSaved {
                        onSaved()
                    } else {
                        dismiss()
                    }
                }
                .disabled(!viewModel.isValid)
            }
            ToolbarItem(placement: .primaryAction) {
                Link(destination: URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!) {
                    Image(systemSymbol: .questionmarkCircle)
                }
            }
        }
        .confirmationDialog(
            L10n.Watch.Configurator.Delete.title,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Watch.Configurator.Delete.button, role: .destructive) {
                viewModel.delete()
                dismiss()
            }
            Button(L10n.cancelLabel, role: .cancel) {}
        } message: {
            Text(L10n.Watch.Configurator.Delete.message)
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Sections

    private var templateSection: some View {
        Section {
            TextField(
                L10n.Watch.Configurator.Rows.DisplayName.title,
                text: $viewModel.name,
                prompt: Text(viewModel.family.name)
            )

            serverPicker

            NavigationLink {
                TemplateStylePicker(selected: $viewModel.displayTemplate, options: viewModel.family.templates)
                    .onDisappear { viewModel.onDisplayTemplateChange() }
            } label: {
                HStack {
                    Text(L10n.Watch.Configurator.Rows.Template.title)
                    Spacer()
                    Text(viewModel.displayTemplate.style)
                        .foregroundColor(.secondary)
                }
            }

            Toggle(L10n.Watch.Configurator.Rows.IsPublic.title, isOn: $viewModel.isPublic)
        }
    }

    @ViewBuilder
    private var serverPicker: some View {
        let allServers = Current.servers.all
        if allServers.count > 1 {
            Picker(L10n.Settings.ConnectionSection.servers, selection: $viewModel.serverIdentifier) {
                ForEach(allServers, id: \.identifier.rawValue) { server in
                    Text(server.info.name).tag(Optional(server.identifier.rawValue))
                }
            }
        }
    }

    @ViewBuilder
    private var column2AlignmentSection: some View {
        if viewModel.supportsColumn2Alignment {
            Section {
                Picker(
                    L10n.Watch.Configurator.Rows.Column2Alignment.title,
                    selection: $viewModel.column2Alignment
                ) {
                    ForEach(ComplicationEditViewModel.Column2Alignment.allCases) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var iconSection: some View {
        if viewModel.hasImage {
            Section {
                IconSearchPicker(
                    selectedIcon: $viewModel.icon,
                    tintColor: viewModel.iconColor,
                    title: L10n.Watch.Configurator.Rows.Icon.Choose.title
                )
                ColorPicker(
                    L10n.Watch.Configurator.Rows.Icon.Color.title,
                    selection: $viewModel.iconColor,
                    supportsOpacity: false
                )
            } header: {
                Text(L10n.Watch.Configurator.Sections.Icon.header)
            } footer: {
                Text(L10n.Watch.Configurator.Sections.Icon.footer)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text(L10n.Watch.Configurator.Delete.button)
                    .foregroundColor(Color(.systemRed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Template picker

private struct TemplateStylePicker: View {
    @Binding var selected: ComplicationTemplate
    let options: [ComplicationTemplate]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(options, id: \.rawValue) { option in
            Button {
                selected = option
                dismiss()
            } label: {
                HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        Text(option.style)
                            .foregroundColor(.primary)
                        Text(option.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if option == selected {
                        Image(systemSymbol: .checkmark)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(L10n.Watch.Configurator.Rows.Template.selectorTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Gauge section

private struct ComplicationEditGaugeSection: View {
    @ObservedObject var viewModel: ComplicationEditViewModel
    @StateObject private var renderer: TemplateRenderer

    init(viewModel: ComplicationEditViewModel) {
        self.viewModel = viewModel
        let server = viewModel.server ?? Current.servers.all.first!
        _renderer = StateObject(wrappedValue: TemplateRenderer(server: server, displayResult: {
            try ComplicationEditViewModel.validatePercentile($0)
        }))
    }

    var body: some View {
        if viewModel.hasGauge {
            TemplatePreviewSection(
                header: L10n.Watch.Configurator.Sections.Gauge.header,
                footer: L10n.Watch.Configurator.Sections.Gauge.footer,
                title: L10n.Watch.Configurator.Rows.Gauge.title,
                placeholder: "{{ range(1, 100) | random / 100.0 }}",
                template: $viewModel.gaugeTemplate,
                renderer: renderer
            )
            .onChange(of: viewModel.serverIdentifier) { _ in
                if let server = viewModel.server {
                    renderer.updateServer(server)
                }
            }

            Section {
                ColorPicker(
                    L10n.Watch.Configurator.Rows.Gauge.Color.title,
                    selection: $viewModel.gaugeColor,
                    supportsOpacity: false
                )
                Picker(
                    L10n.Watch.Configurator.Rows.Gauge.GaugeType.title,
                    selection: $viewModel.gaugeType
                ) {
                    ForEach(ComplicationEditViewModel.GaugeType.allCases) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isGaugeTypeForced)

                Picker(
                    L10n.Watch.Configurator.Rows.Gauge.Style.title,
                    selection: $viewModel.gaugeStyle
                ) {
                    ForEach(ComplicationEditViewModel.GaugeStyle.allCases) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Ring section

private struct ComplicationEditRingSection: View {
    @ObservedObject var viewModel: ComplicationEditViewModel
    @StateObject private var renderer: TemplateRenderer

    init(viewModel: ComplicationEditViewModel) {
        self.viewModel = viewModel
        let server = viewModel.server ?? Current.servers.all.first!
        _renderer = StateObject(wrappedValue: TemplateRenderer(server: server, displayResult: {
            try ComplicationEditViewModel.validatePercentile($0)
        }))
    }

    var body: some View {
        if viewModel.hasRing {
            TemplatePreviewSection(
                header: L10n.Watch.Configurator.Sections.Ring.header,
                footer: L10n.Watch.Configurator.Sections.Ring.footer,
                title: L10n.Watch.Configurator.Rows.Ring.Value.title,
                placeholder: "{{ range(1, 100) | random / 100.0 }}",
                template: $viewModel.ringTemplate,
                renderer: renderer
            )
            .onChange(of: viewModel.serverIdentifier) { _ in
                if let server = viewModel.server {
                    renderer.updateServer(server)
                }
            }

            Section {
                Picker(
                    L10n.Watch.Configurator.Rows.Ring.RingType.title,
                    selection: $viewModel.ringType
                ) {
                    ForEach(ComplicationEditViewModel.RingType.allCases) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                ColorPicker(
                    L10n.Watch.Configurator.Rows.Ring.Color.title,
                    selection: $viewModel.ringColor,
                    supportsOpacity: false
                )
            }
        }
    }
}

// MARK: - Text area sections

private struct ComplicationEditTextAreas: View {
    @ObservedObject var viewModel: ComplicationEditViewModel

    var body: some View {
        ForEach(viewModel.activeTextAreas, id: \.slug) { area in
            TextAreaEditor(viewModel: viewModel, area: area)
        }
    }
}

private struct TextAreaEditor: View {
    @ObservedObject var viewModel: ComplicationEditViewModel
    let area: ComplicationTextAreas

    @StateObject private var renderer: TemplateRenderer

    init(viewModel: ComplicationEditViewModel, area: ComplicationTextAreas) {
        self.viewModel = viewModel
        self.area = area
        let server = viewModel.server ?? Current.servers.all.first!
        _renderer = StateObject(wrappedValue: TemplateRenderer(server: server, displayResult: {
            try ComplicationEditViewModel.validateText($0)
        }))
    }

    var body: some View {
        // Bindings driven through a helper to avoid default-value churn.
        let textBinding = Binding<String>(
            get: { viewModel.textAreaValues[area.slug]?.text ?? "" },
            set: { newValue in
                var current = viewModel.textAreaValues[area.slug] ?? .init(text: "", color: .green)
                current.text = newValue
                viewModel.textAreaValues[area.slug] = current
            }
        )
        let colorBinding = Binding<Color>(
            get: { viewModel.textAreaValues[area.slug]?.color ?? .green },
            set: { newValue in
                var current = viewModel.textAreaValues[area.slug] ?? .init(text: "", color: .green)
                current.color = newValue
                viewModel.textAreaValues[area.slug] = current
            }
        )

        TemplatePreviewSection(
            header: area.label,
            footer: area.description,
            title: area.label,
            placeholder: "{{ states(\"weather.temperature\") }}",
            template: textBinding,
            renderer: renderer
        )
        .onChange(of: viewModel.serverIdentifier) { _ in
            if let server = viewModel.server {
                renderer.updateServer(server)
            }
        }

        Section {
            ColorPicker(
                L10n.Watch.Configurator.Rows.Color.title,
                selection: colorBinding,
                supportsOpacity: false
            )
        }
    }
}
