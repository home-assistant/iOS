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
    @State private var showAllZones = false

    var body: some View {
        Form {
            zoneSections
            permissionsSection
            locationHistorySection
            updateSourcesSection
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
        if !viewModel.zones.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.oneAndHalf) {
                        ForEach(viewModel.sortedZones) { zone in
                            NavigationLink {
                                LocationZoneMapView(
                                    title: zone.name,
                                    coordinate: zone.coordinate,
                                    radius: zone.radius
                                )
                            } label: {
                                ZoneCardView(
                                    zone: zone,
                                    distanceText: viewModel.formattedDistance(to: zone),
                                    serverName: viewModel.hasMultipleServers ? zone.serverName : nil
                                )
                                .frame(width: 280)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(
                    top: DesignSystem.Spaces.one,
                    leading: .zero,
                    bottom: DesignSystem.Spaces.one,
                    trailing: .zero
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .background(
                    NavigationLink(isActive: $showAllZones) {
                        ZonesListView(viewModel: viewModel)
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)
                )
            } header: {
                HStack {
                    Text(L10n.SettingsDetails.Location.Zones.header)
                    Spacer()
                    Button(L10n.SettingsDetails.Location.Zones.ShowAll.title) {
                        showAllZones = true
                    }
                    .font(DesignSystem.Font.footnote)
                }
            } footer: {
                Text(L10n.SettingsDetails.Location.Zones.footer)
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

extension LocationSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.SettingsDetails.Location.LocationPermission.title),
            SettingsSearchEntry(L10n.SettingsDetails.Location.LocationAccuracy.title),
            SettingsSearchEntry(L10n.SettingsDetails.Location.BackgroundRefresh.title),
            SettingsSearchEntry(L10n.Settings.LocationHistory.title),
            SettingsSearchEntry(L10n.SettingsDetails.Location.updateLocation),
            SettingsSearchEntry(L10n.SettingsDetails.Location.Updates.Zone.title),
            SettingsSearchEntry(L10n.SettingsDetails.Location.Updates.Background.title),
            SettingsSearchEntry(L10n.SettingsDetails.Location.Updates.Significant.title),
            SettingsSearchEntry(L10n.SettingsDetails.Location.Zones.header),
        ]
    }
}
