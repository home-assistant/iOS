import SFSafeSymbols
import Shared
import SwiftUI

/// Vertical list of all tracked zone cards, reached from the "Show all" button in
/// the Location settings' horizontal zones section. When multiple servers are
/// onboarded the list can be filtered per server.
struct ZonesListView: View {
    @ObservedObject var viewModel: LocationSettingsViewModel
    @State private var selectedServerIdentifier: String?

    var body: some View {
        List {
            ForEach(filteredZones) { zone in
                ZoneCardView(
                    zone: zone,
                    distanceText: viewModel.formattedDistance(to: zone),
                    serverName: viewModel.hasMultipleServers ? zone.serverName : nil
                )
                .listRowInsets(EdgeInsets(
                    top: DesignSystem.Spaces.oneAndHalf,
                    leading: .zero,
                    bottom: DesignSystem.Spaces.oneAndHalf,
                    trailing: .zero
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                // Hidden link so the whole card navigates without the List drawing
                // a disclosure chevron next to it.
                .background(
                    NavigationLink {
                        LocationZoneMapView(
                            title: zone.name,
                            coordinate: zone.coordinate,
                            radius: zone.radius
                        )
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.SettingsDetails.Location.Zones.header)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.hasMultipleServers {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker(
                            L10n.SettingsDetails.Location.Zones.Filter.allServers,
                            selection: $selectedServerIdentifier
                        ) {
                            Text(L10n.SettingsDetails.Location.Zones.Filter.allServers)
                                .tag(String?.none)
                            ForEach(Current.servers.all, id: \.identifier.rawValue) { server in
                                Text(server.info.name)
                                    .tag(String?.some(server.identifier.rawValue))
                            }
                        }
                    } label: {
                        Image(
                            systemSymbol: selectedServerIdentifier == nil
                                ? .line3HorizontalDecreaseCircle
                                : .line3HorizontalDecreaseCircleFill
                        )
                    }
                }
            }
        }
    }

    private var filteredZones: [LocationZoneItem] {
        guard let selectedServerIdentifier else { return viewModel.sortedZones }
        return viewModel.sortedZones.filter { $0.serverIdentifier == selectedServerIdentifier }
    }
}

#Preview {
    NavigationView {
        ZonesListView(viewModel: LocationSettingsViewModel())
    }
}
