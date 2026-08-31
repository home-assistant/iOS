import SFSafeSymbols
import Shared
import SwiftUI

/// The watch-compatible entities of one device, pushed by tapping a device section header on the
/// area screen. Same two sections and same rows as the area screen; the screen's own device is
/// unwrapped into loose rows because every row already belongs to the device the screen is named
/// after, while its child devices keep their own sections. The navigation bar stays hidden — the
/// custom header provides the back button, matching `WatchAreaEntitiesView`.
struct WatchDeviceEntitiesView: View {
    let name: String
    @StateObject private var viewModel: WatchDeviceEntitiesViewModel
    @Environment(\.dismiss) private var dismiss

    init(deviceId: String, serverId: String, name: String) {
        self.name = name
        self._viewModel = .init(wrappedValue: .init(deviceId: deviceId, serverId: serverId))
    }

    var body: some View {
        List {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemSymbol: .chevronLeft)
                }
                .buttonStyle(.plain)
                .circularGlassOrLegacyBackground()
                Text(verbatim: name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowBackground(Color.clear)
            .padding(.top, DesignSystem.Spaces.one)
            if let sections = viewModel.sections {
                if sections.isEmpty {
                    Text(verbatim: L10n.Watch.Home.Device.empty)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    if !sections.controls.isEmpty {
                        Section {
                            ForEach(sections.controls.ungrouped) { entry in
                                WatchMagicViewRow(item: entry.item, itemInfo: entry.info)
                            }
                        } header: {
                            Text(verbatim: L10n.Watch.Home.Areas.Section.Controls.title)
                        }
                        ForEach(sections.controls.deviceGroups) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    WatchMagicViewRow(item: entry.item, itemInfo: entry.info)
                                }
                            } header: {
                                WatchAreaDeviceSectionHeader(
                                    group: group,
                                    serverId: viewModel.serverId,
                                    showsParentName: false
                                )
                            }
                        }
                    }
                    if !sections.sensors.isEmpty {
                        Section {
                            ForEach(sections.sensors.ungrouped) { entry in
                                WatchMagicViewRow(item: entry.item, itemInfo: entry.info)
                            }
                        } header: {
                            Text(verbatim: L10n.Watch.Home.Areas.Section.Sensors.title)
                        }
                        ForEach(sections.sensors.deviceGroups) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    WatchMagicViewRow(item: entry.item, itemInfo: entry.info)
                                }
                            } header: {
                                WatchAreaDeviceSectionHeader(
                                    group: group,
                                    serverId: viewModel.serverId,
                                    showsParentName: false
                                )
                            }
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
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationStack {
        WatchDeviceEntitiesView(deviceId: "device-1", serverId: "1", name: "Living Room Lamp")
    }
}
