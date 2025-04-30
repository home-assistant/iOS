import Combine
import CoreMotion
import Foundation
import PromiseKit
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

struct SensorListView: View {
    @StateObject private var viewModel = SensorListViewModel()

    private let periodicOptions: [TimeInterval?] = {
        var options: [TimeInterval?] = [nil, 20, 60, 120, 300, 600, 900, 1800, 3600]
        if Current.appConfiguration == .debug {
            options.insert(contentsOf: [2, 5], at: 1)
        }
        return options
    }()

    private let sinceFormatter: DateFormatter = {
        let sinceFormatter = DateFormatter()
        sinceFormatter.formattingContext = .middleOfSentence
        sinceFormatter.dateStyle = .none
        sinceFormatter.timeStyle = .medium
        return sinceFormatter
    }()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .motionSensorIcon,
                title: L10n.SettingsSensors.title,
                subtitle: L10n.SettingsSensors.body
            )
            periodicUpdaterRow
            motionFocusPermissionNeededView
            sensorsList
        }
        .removeListsPaddingWithAppleLikeHeader()
        .onAppear {
            viewModel.updatePermissions()
            viewModel.refresh()
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(L10n.SettingsSensors.LoadingError.title),
                message: Text(viewModel.alertMessage ?? ""),
                primaryButton: .default(Text(L10n.retryLabel)) {
                    viewModel.refresh()
                },
                secondaryButton: .cancel(Text(L10n.cancelLabel))
            )
        }
    }

    private var periodicUpdaterRow: some View {
        Section(footer: Text(
            PeriodicUpdateManager.supportsBackgroundPeriodicUpdates ? L10n.SettingsSensors
                .PeriodicUpdate.descriptionMac : L10n.SettingsSensors.PeriodicUpdate.description
        )) {
            Picker(
                selection: $viewModel.periodicUpdateInterval,
                label: Text(L10n.SettingsSensors.PeriodicUpdate.title)
            ) {
                ForEach(periodicOptions, id: \.self) { option in
                    Text(periodicUodateDisplayText(for: option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.periodicUpdateInterval) { newValue in
                viewModel.setPeriodicUpdateInterval(newValue)
            }
        }
    }

    private var sensorsList: some View {
        Section {
            ForEach(viewModel.sensors, id: \.UniqueID) { sensor in
                NavigationLink(destination: SensorDetailView(sensor: sensor)) {
                    SensorRow(sensor: sensor, isEnabled: Current.sensors.isEnabled(sensor: sensor))
                }
            }
        } header: {
            Text(L10n.SettingsSensors.Sensors.header)
        } footer: {
            if let lastUpdate = viewModel.lastUpdateDate {
                Text("\(L10n.SettingsSensors.LastUpdated.prefix) ") +
                    Text(lastUpdate, style: .date) +
                    Text(" ") +
                    Text(lastUpdate, style: .time)
            }
        }
    }

    @ViewBuilder
    private var motionFocusPermissionNeededView: some View {
        if viewModel.motionAuthorizationStatus != nil || viewModel.focusAuthorizationStatus != nil {
            Section(L10n.SettingsSensors.Permissions.header) {
                motionAuthorizationButton
                focusAuthorizationButton
            }
        }
    }

    private var motionAuthorizationButton: some View {
        Button(action: {
            if viewModel.motionAuthorizationStatus == .notDetermined {
                viewModel.requestMotionAuthorization {}
            } else {
                viewModel.openMotionSettings()
            }
        }) {
            HStack {
                Text(L10n.SettingsDetails.Location.MotionPermission.title)
                Spacer()
                Text(motionStatusDescription(viewModel.motionAuthorizationStatus ?? .notDetermined))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var focusAuthorizationButton: some View {
        Button(action: {
            if viewModel.focusAuthorizationStatus == .notDetermined {
                viewModel.requestFocusAuthorization {}
            } else {
                viewModel.openFocusSettings()
            }
        }) {
            HStack {
                Text(L10n.SettingsSensors.FocusPermission.title)
                Spacer()
                Text(focusStatusDescription(viewModel.focusAuthorizationStatus ?? .notDetermined))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func periodicUodateDisplayText(for value: TimeInterval?) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        switch value {
        case .none:
            return L10n.SettingsSensors.PeriodicUpdate.off
        case let .some(interval):
            return formatter.string(from: interval) ?? ""
        }
    }

    private func motionStatusDescription(_ status: CMAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return L10n.SettingsDetails.Location.MotionPermission.needsRequest
        case .restricted:
            return L10n.SettingsDetails.Location.MotionPermission.restricted
        case .denied:
            return L10n.SettingsDetails.Location.MotionPermission.denied
        case .authorized:
            return L10n.SettingsDetails.Location.MotionPermission.enabled
        @unknown default:
            return L10n.SettingsDetails.Location.MotionPermission.needsRequest
        }
    }

    private func focusStatusDescription(_ status: FocusStatusWrapper.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return L10n.SettingsDetails.Location.FocusPermission.needsRequest
        case .restricted:
            return L10n.SettingsDetails.Location.FocusPermission.restricted
        case .denied:
            return L10n.SettingsDetails.Location.FocusPermission.denied
        case .authorized:
            return L10n.SettingsDetails.Location.FocusPermission.enabled
        @unknown default:
            return L10n.SettingsDetails.Location.FocusPermission.needsRequest
        }
    }
}
