import CoreLocation
import MapKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Card presentation of a tracked zone: a map thumbnail, the distance from the user's
/// current position and a shortcut to get directions in Maps. Purely presentational —
/// navigation to the full-screen map is owned by the containing view.
struct ZoneCardView: View {
    let zone: LocationZoneItem
    let distanceText: String?
    /// Shown under the zone name; pass only when multiple servers are onboarded.
    let serverName: String?

    var body: some View {
        VStack(spacing: .zero) {
            ZoneMapSnapshotView(coordinate: zone.coordinate, radius: zone.radius)
                .frame(height: 140)
                .overlay(alignment: .topTrailing) {
                    Image(systemSymbol: .arrowUpLeftAndArrowDownRight)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(DesignSystem.Spaces.half)
                        .background(.thinMaterial, in: Circle())
                        .padding(DesignSystem.Spaces.one)
                }

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                        Text(zone.name)
                            .font(DesignSystem.Font.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let serverName {
                            Text(serverName)
                                .font(DesignSystem.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(
                        zone.trackingEnabled
                            ? L10n.SettingsDetails.Location.Zones.TrackingEnabled.label
                            : L10n.SettingsDetails.Location.Zones.TrackingDisabled.label
                    )
                    .font(DesignSystem.Font.caption)
                    .foregroundStyle(zone.trackingEnabled ? Color.haPrimary : Color.secondary)
                    .padding(.horizontal, DesignSystem.Spaces.one)
                    .padding(.vertical, DesignSystem.Spaces.micro)
                    .background(
                        (zone.trackingEnabled ? Color.haPrimary : Color.secondary).opacity(0.15),
                        in: Capsule()
                    )
                }

                if let distanceText {
                    HStack(spacing: DesignSystem.Spaces.half) {
                        Image(systemSymbol: .location)
                        Text(L10n.SettingsDetails.Location.Zones.Distance.label(distanceText))
                    }
                    .font(DesignSystem.Font.subheadline)
                    .foregroundStyle(.secondary)
                }

                Text(L10n.SettingsDetails.Location.Zones.Radius.detail(Int(zone.radius)))
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)

                if let beaconUUID = zone.beaconUUID {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L10n.SettingsDetails.Location.Zones.BeaconUuid.title)
                        Spacer()
                        Text(beaconUUID)
                            .foregroundStyle(.secondary)
                    }
                    .font(DesignSystem.Font.caption)
                }

                if let beaconMajor = zone.beaconMajor {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L10n.SettingsDetails.Location.Zones.BeaconMajor.title)
                        Spacer()
                        Text(beaconMajor)
                            .foregroundStyle(.secondary)
                    }
                    .font(DesignSystem.Font.caption)
                }

                if let beaconMinor = zone.beaconMinor {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L10n.SettingsDetails.Location.Zones.BeaconMinor.title)
                        Spacer()
                        Text(beaconMinor)
                            .foregroundStyle(.secondary)
                    }
                    .font(DesignSystem.Font.caption)
                }

                Button {
                    openDirections()
                } label: {
                    HStack(spacing: DesignSystem.Spaces.half) {
                        Image(systemSymbol: .arrowTriangleTurnUpRightDiamondFill)
                        Text(L10n.SettingsDetails.Location.Zones.Directions.title)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaryButton)
                .padding(.top, DesignSystem.Spaces.half)
            }
            .padding(DesignSystem.Spaces.two)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
    }

    private func openDirections() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: zone.coordinate))
        mapItem.name = zone.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault,
        ])
    }
}

#Preview {
    NavigationView {
        List {
            ZoneCardView(
                zone: LocationZoneItem(zone: AppZone(
                    entityId: "zone.home",
                    serverIdentifier: "server1",
                    friendlyName: "Home",
                    latitude: 37.3349,
                    longitude: -122.0090,
                    radius: 100
                )),
                distanceText: "1.2 km",
                serverName: "Home"
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}
