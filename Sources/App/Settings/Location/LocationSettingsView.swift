import CoreLocation
import MapKit
import PromiseKit
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

struct LocationSettingsView: View {
    @StateObject private var viewModel = LocationSettingsViewModel()
    @State private var showManualUpdateError = false
    @State private var manualUpdateErrorMessage = ""
    @State private var isUpdatingLocation = false

    var body: some View {
        Form {
            permissionsSection
            locationHistorySection
            updateSourcesSection
            zoneSections
            zonesFooterSection
        }
        .navigationTitle(L10n.SettingsDetails.Location.title)
        .onAppear {
            viewModel.onAppear()
        }
        .alert(L10n.errorLabel, isPresented: $showManualUpdateError) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(manualUpdateErrorMessage)
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            LocationPermissionStatusRow(
                title: L10n.SettingsDetails.Location.LocationPermission.title,
                value: viewModel.locationPermissionDescription
            ) {
                viewModel.handleLocationPermissionTap()
            }

            LocationPermissionStatusRow(
                title: L10n.SettingsDetails.Location.LocationAccuracy.title,
                value: viewModel.locationAccuracyDescription
            ) {
                URLOpener.shared.openSettings(destination: .location, completionHandler: nil)
            }

            if !Current.isCatalyst {
                LocationPermissionStatusRow(
                    title: L10n.SettingsDetails.Location.BackgroundRefresh.title,
                    value: viewModel.backgroundRefreshDescription
                ) {
                    URLOpener.shared.openSettings(destination: .backgroundRefresh, completionHandler: nil)
                }
            }
        }
    }

    // MARK: - Location history + manual update

    private var locationHistorySection: some View {
        Section {
            NavigationLink {
                LocationHistoryListView()
            } label: {
                Text(L10n.Settings.LocationHistory.title)
            }

            Button {
                triggerManualUpdate()
            } label: {
                HStack {
                    Text(L10n.SettingsDetails.Location.updateLocation)
                        .foregroundColor(.primary)
                    Spacer()
                    if isUpdatingLocation {
                        ProgressView()
                    }
                }
            }
            .disabled(isUpdatingLocation)
        }
    }

    // MARK: - Update sources toggles

    private var updateSourcesSection: some View {
        Section {
            Toggle(L10n.SettingsDetails.Location.Updates.Zone.title, isOn: $viewModel.zoneEnabled)
                .disabled(viewModel.isZoneToggleDisabled)

            if !Current.isCatalyst {
                Toggle(
                    L10n.SettingsDetails.Location.Updates.Background.title,
                    isOn: $viewModel.backgroundFetchEnabled
                )
                .disabled(viewModel.isBackgroundFetchToggleDisabled)
            }

            Toggle(
                L10n.SettingsDetails.Location.Updates.Significant.title,
                isOn: $viewModel.significantLocationChangeEnabled
            )
            .disabled(viewModel.isSignificantLocationChangeToggleDisabled)

            Toggle(
                L10n.SettingsDetails.Location.Updates.Notification.title,
                isOn: $viewModel.pushNotificationsEnabled
            )
            .disabled(viewModel.isPushNotificationsToggleDisabled)
        } header: {
            Text(L10n.SettingsDetails.Location.Updates.header)
        } footer: {
            Text(L10n.SettingsDetails.Location.Updates.footer)
        }
    }

    // MARK: - Zones

    @ViewBuilder
    private var zoneSections: some View {
        ForEach(viewModel.zones) { zone in
            Section {
                Toggle(
                    L10n.SettingsDetails.Location.Zones.EnterExitTracked.title,
                    isOn: .constant(zone.trackingEnabled)
                )
                .disabled(true)

                NavigationLink {
                    LocationZoneMapView(
                        title: zone.name,
                        coordinate: zone.coordinate,
                        radius: zone.radius
                    )
                } label: {
                    HStack {
                        Text(L10n.SettingsDetails.Location.Zones.Location.title)
                        Spacer()
                        Text(zone.formattedCoordinate)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text(L10n.SettingsDetails.Location.Zones.Radius.title)
                    Spacer()
                    Text(L10n.SettingsDetails.Location.Zones.Radius.label(Int(zone.radius)))
                        .foregroundColor(.secondary)
                }

                if let beaconUUID = zone.beaconUUID {
                    HStack {
                        Text(L10n.SettingsDetails.Location.Zones.BeaconUuid.title)
                        Spacer()
                        Text(beaconUUID)
                            .foregroundColor(.secondary)
                    }
                }

                if let beaconMajor = zone.beaconMajor {
                    HStack {
                        Text(L10n.SettingsDetails.Location.Zones.BeaconMajor.title)
                        Spacer()
                        Text(beaconMajor)
                            .foregroundColor(.secondary)
                    }
                }

                if let beaconMinor = zone.beaconMinor {
                    HStack {
                        Text(L10n.SettingsDetails.Location.Zones.BeaconMinor.title)
                        Spacer()
                        Text(beaconMinor)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(zone.name)
            }
        }
    }

    @ViewBuilder
    private var zonesFooterSection: some View {
        if !viewModel.zones.isEmpty {
            Section {
                Text(L10n.SettingsDetails.Location.Zones.footer)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func triggerManualUpdate() {
        isUpdatingLocation = true
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.ensure {
            isUpdatingLocation = false
        }.catch { error in
            manualUpdateErrorMessage = error.localizedDescription
            showManualUpdateError = true
        }
    }
}

// MARK: - Permission status row

struct LocationPermissionStatusRow: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
                Image(systemSymbol: .chevronRight)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
        }
    }
}

// MARK: - Zone map view

struct LocationZoneMapView: View {
    let title: String
    let coordinate: CLLocationCoordinate2D
    let radius: Double

    var body: some View {
        ZoneMapRepresentable(coordinate: coordinate, radius: radius)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title.isEmpty ? coordinateTitle : title)
            .navigationBarTitleDisplayMode(.inline)
    }

    private var coordinateTitle: String {
        CoordinateFormatter.string(from: coordinate)
    }
}

private struct ZoneMapRepresentable: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let radius: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true

        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        mapView.addAnnotation(pin)

        let circle = MKCircle(center: coordinate, radius: radius)
        mapView.addOverlay(circle)

        // Don't zoom in tighter than 400m even for very small zones, so the radius circle stays readable.
        let regionMeters = max(radius * 4, 400)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: regionMeters,
            longitudinalMeters: regionMeters
        )
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = .systemRed
            renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.1)
            renderer.lineWidth = 1
            renderer.lineDashPattern = [2, 5]
            return renderer
        }
    }
}

#Preview {
    NavigationView {
        LocationSettingsView()
    }
}
