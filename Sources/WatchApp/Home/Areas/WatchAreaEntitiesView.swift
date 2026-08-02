import SFSafeSymbols
import Shared
import SwiftUI

/// The watch-compatible entities of one area, pushed by `WatchAreaRow` through the home screen's
/// `NavigationStack`. Rows are the same `WatchMagicViewRow` the home screen uses, so entities can
/// be controlled exactly as if they were configured items. The navigation bar stays hidden — the
/// custom header provides the back button, matching `WatchFolderContentView`.
struct WatchAreaEntitiesView: View {
    @StateObject private var viewModel: WatchAreaEntitiesViewModel
    @Environment(\.dismiss) private var dismiss

    init(areaId: String, serverId: String) {
        self._viewModel = .init(wrappedValue: .init(areaId: areaId, serverId: serverId))
    }

    var body: some View {
        List {
            header
            if let content = viewModel.content {
                if content.isEmpty {
                    Text(verbatim: L10n.Watch.Home.Areas.empty)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    if !content.controls.isEmpty {
                        Section {
                            ForEach(content.controls) { entry in
                                WatchMagicViewRow(item: entry.item, itemInfo: entry.info)
                            }
                        } header: {
                            Text(verbatim: L10n.Watch.Home.Areas.Section.Controls.title)
                        }
                    }
                    if !content.sensors.isEmpty {
                        Section {
                            ForEach(content.sensors) { entry in
                                WatchMagicViewRow(item: entry.item, itemInfo: entry.info)
                            }
                        } header: {
                            Text(verbatim: L10n.Watch.Home.Areas.Section.Sensors.title)
                        }
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .ignoresSafeArea([.all], edges: .top)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .modify { view in
            if #available(watchOS 11.0, *) {
                view.toolbarVisibility(.hidden, for: .navigationBar)
            } else {
                view.toolbar(.hidden, for: .navigationBar)
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemSymbol: .chevronLeft)
            }
            .buttonStyle(.plain)
            .circularGlassOrLegacyBackground()
            Text(viewModel.areaName ?? L10n.Watch.Home.Areas.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationStack {
        WatchAreaEntitiesView(areaId: "living_room", serverId: "1")
    }
}
