import SFSafeSymbols
import Shared
import SwiftUI

struct FocusSettingsView: View {
    @StateObject private var viewModel = FocusSettingsViewModel()
    @State private var isAddingName = false
    @State private var newName = ""

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .moonWaningCrescentIcon,
                title: L10n.Focus.title,
                subtitle: L10n.Focus.subtitle
            )
            Section {
                NavigationLink(destination: FocusHowItWorksView()) {
                    Label(L10n.Focus.HowItWorks.title, systemSymbol: .questionmarkCircle)
                }
            }
            Section(
                header: Text(L10n.Focus.Names.header),
                footer: Text(L10n.Focus.Names.footer)
            ) {
                if viewModel.focusNames.isEmpty {
                    Text(L10n.Focus.Names.empty)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.focusNames) { focusName in
                    HStack {
                        Text(focusName.name)
                        if focusName.name == viewModel.activeFocusName {
                            Spacer()
                            Text(L10n.Focus.Names.lastReported)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.delete(focusName)
                        } label: {
                            Label(L10n.delete, systemSymbol: .trash)
                        }
                    }
                }
                Button {
                    newName = ""
                    isAddingName = true
                } label: {
                    Label(L10n.Focus.Names.add, systemSymbol: .plus)
                }
                .alert(L10n.Focus.Names.add, isPresented: $isAddingName) {
                    TextField(L10n.Focus.Names.placeholder, text: $newName)
                        .autocorrectionDisabled()
                    Button(L10n.cancelLabel, role: .cancel) {}
                    Button(L10n.addButtonLabel) {
                        viewModel.add(name: newName)
                    }
                    .disabled(!viewModel.canAdd(name: newName))
                } message: {
                    Text(L10n.Focus.Names.addMessage)
                }
            }
            Section(header: Text(L10n.Focus.Reported.header)) {
                HStack {
                    Text(L10n.Focus.Reported.currentName)
                    Spacer()
                    Text(viewModel.activeFocusName ?? L10n.Focus.Reported.noneYet)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.isFocusSensorEnabled {
                    NavigationLink {
                        SensorListView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                Text(L10n.Focus.SensorDisabled.title)
                                Text(L10n.Focus.SensorDisabled.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemSymbol: .exclamationmarkTriangle)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                if !viewModel.isFocusPermissionGranted {
                    NavigationLink {
                        SensorPermissionsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                Text(L10n.Focus.PermissionMissing.title)
                                Text(L10n.Focus.PermissionMissing.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemSymbol: .exclamationmarkTriangle)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
        .listTopContentMargin()
    }
}

extension FocusSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Focus.Names.header),
            SettingsSearchEntry(L10n.Focus.Names.add),
            SettingsSearchEntry(L10n.Focus.HowItWorks.title),
        ]
    }
}

#Preview {
    NavigationView {
        FocusSettingsView()
    }
}
