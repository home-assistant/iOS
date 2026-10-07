import SFSafeSymbols
import Shared
import SwiftUI

struct SensorPermissionsView: View {
    @StateObject private var viewModel = SensorPermissionsViewModel()

    var body: some View {
        List {
            ForEach(viewModel.availablePermissions) { permission in
                Section {
                    Button {
                        viewModel.handleTap(on: permission)
                    } label: {
                        HStack(spacing: DesignSystem.Spaces.two) {
                            Image(uiImage: permission.icon.image(
                                ofSize: .init(width: 24, height: 24),
                                color: .haPrimary
                            ))
                            .frame(width: DesignSystem.Spaces.three)
                            Text(permission.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(viewModel.status(for: permission).description)
                                .foregroundStyle(viewModel.status(for: permission).color)
                            Image(systemSymbol: .chevronRight)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        }
                    }
                } footer: {
                    Text(permission.usageDescription)
                }
            }
        }
        .navigationTitle(L10n.SettingsSensors.Permissions.header)
        .onAppear {
            viewModel.update()
        }
        .alert(L10n.errorLabel, isPresented: $viewModel.showAlert) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .listTopContentMargin()
    }
}

extension SensorPermissionsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [SettingsSearchEntry(L10n.SettingsSensors.Permissions.header)]
            + SensorPermission.allCases.map { SettingsSearchEntry($0.title) }
    }
}

#Preview {
    NavigationView {
        SensorPermissionsView()
    }
}
