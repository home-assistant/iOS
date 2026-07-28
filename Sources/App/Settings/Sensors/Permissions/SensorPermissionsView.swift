import SFSafeSymbols
import Shared
import SwiftUI

struct SensorPermissionsView: View {
    @ObservedObject var viewModel: SensorPermissionsViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.availablePermissions) { permission in
                    Button {
                        viewModel.handleTap(on: permission)
                    } label: {
                        HStack(spacing: DesignSystem.Spaces.two) {
                            Image(systemSymbol: permission.symbol)
                                .foregroundStyle(.haPrimary)
                                .frame(width: DesignSystem.Spaces.three)
                            Text(permission.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(viewModel.status(for: permission).description)
                                .foregroundStyle(.secondary)
                            Image(systemSymbol: .chevronRight)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        }
                    }
                }
            } footer: {
                Text(footer)
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
    }

    private var footer: String {
        var paragraphs = [L10n.SettingsSensors.Permissions.footer]
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if viewModel.availablePermissions.contains(.health) {
            paragraphs.append(L10n.SettingsSensors.Permissions.Health.footer)
        }
        #endif
        return paragraphs.joined(separator: "\n\n")
    }
}

#Preview {
    NavigationView {
        SensorPermissionsView(viewModel: SensorPermissionsViewModel())
    }
}
