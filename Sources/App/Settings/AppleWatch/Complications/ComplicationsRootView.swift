import Shared
import SwiftUI
import UIKit

/// Root of the Complications settings screen. Mirrors the CarPlay / Widgets configuration layout:
/// an Apple-like header, the list of the user's complications with an add button, and the legacy
/// complications tucked behind a navigation link.
struct ComplicationsRootView: View {
    @StateObject private var viewModel = ComplicationsRootViewModel()
    @State private var showAdd = false

    var body: some View {
        List {
            header
            yourComplicationsSection

            Section {
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    HStack {
                        Label(L10n.Watch.Complications.Root.reload, systemSymbol: .arrowClockwise)
                        if viewModel.isReloading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isReloading)
            } footer: {
                Text(L10n.Watch.Complications.Root.reloadFooter)
            }

            if viewModel.hasLegacy {
                Section {
                    NavigationLink {
                        ComplicationListView()
                    } label: {
                        Label(
                            title: { Text(L10n.Watch.Complications.Root.legacy) },
                            icon: { Image(systemSymbol: .clockArrowCirclepath) }
                        )
                    }
                } footer: {
                    Text(L10n.Watch.Complications.Root.legacyFooter)
                }
            }

            DebugDatabaseTransferSection(part: .complications) {
                viewModel.load()
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationView { WatchComplicationBuilderEditView(existing: nil) }
        }
        .sheet(item: $viewModel.editing) { config in
            NavigationView { WatchComplicationBuilderEditView(existing: config) }
        }
        .alert(item: $viewModel.reloadAlert) { alert in
            Alert(
                title: Text(verbatim: alert.title),
                message: Text(verbatim: alert.message),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
        .navigationTitle(Text(verbatim: ""))
        .onAppear(perform: viewModel.load)
        .onReceive(NotificationCenter.default.publisher(for: WatchComplicationConfig.didChangeNotification)) { _ in
            viewModel.load()
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
            ForEach(viewModel.configs) { config in
                Button {
                    viewModel.editing = config
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        rowIcon(for: config)
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading) {
                            Text(config.displayName)
                                .foregroundColor(.primary)
                            if let subtitle = viewModel.subtitles[config.id] {
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
                .contextMenu {
                    Button {
                        viewModel.duplicate(config)
                    } label: {
                        Label(L10n.Watch.Complications.Root.duplicate, systemSymbol: .docOnDoc)
                    }
                }
            }
            .onDelete(perform: viewModel.delete)

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
}

#Preview("Complications root") {
    NavigationView { ComplicationsRootView() }
}

extension ComplicationsRootView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Watch.Complications.Root.yourComplications),
            SettingsSearchEntry(L10n.Watch.Complications.Root.new),
            SettingsSearchEntry(L10n.Watch.Complications.Root.reload),
            SettingsSearchEntry(L10n.Watch.Complications.Root.legacy),
        ]
    }
}
