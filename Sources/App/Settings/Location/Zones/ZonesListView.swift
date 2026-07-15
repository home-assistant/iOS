import Shared
import SwiftUI

/// Vertical list of all tracked zone cards, reached from the "Show all" button in
/// the Location settings' horizontal zones section.
struct ZonesListView: View {
    @ObservedObject var viewModel: LocationSettingsViewModel

    var body: some View {
        List {
            ForEach(viewModel.zones) { zone in
                ZoneCardView(
                    zone: zone,
                    distanceText: viewModel.formattedDistance(to: zone)
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
    }
}

#Preview {
    NavigationView {
        ZonesListView(viewModel: LocationSettingsViewModel())
    }
}
