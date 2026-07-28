import CarPlay
import SFSafeSymbols
import Shared
import SwiftUI

struct CarPlayTabsSelectionView: View {
    @ObservedObject var viewModel: CarPlayConfigurationViewModel

    @State private var showAddTabSheet = false
    @State private var newTabName = ""

    var body: some View {
        List {
            Section {
                ForEach(viewModel.config.tabs, id: \.rawValue) { tab in
                    activeTabRow(tab)
                }
                .onMove { indices, newOffset in
                    viewModel.moveTab(from: indices, to: newOffset)
                }
                .onDelete { indexSet in
                    viewModel.deleteTab(at: indexSet)
                }
                addTabButton
            } header: {
                Text(L10n.CarPlay.Tabs.Active.title)
            } footer: {
                Text(
                    L10n.CarPlay.Tabs.Active.DeleteAction.title + "\n"
                        + L10n.CarPlay.Config.Tabs.Maximum.footer(CPTabBarTemplate.maximumTabCount)
                )
            }
            if !inactiveTabs.isEmpty {
                Section(L10n.CarPlay.Tabs.Inactive.title) {
                    ForEach(inactiveTabs, id: \.rawValue) { tab in
                        Button {
                            viewModel.updateTab(tab, active: true)
                        } label: {
                            HStack {
                                Text(viewModel.config.name(for: tab))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemSymbol: .plusCircleFill)
                                    .foregroundStyle(.white, .green)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTabSheet) {
            addTabSheet
        }
    }

    /// Folder-backed tabs navigate to their item management screen; built-in tabs keep the
    /// tap-to-deactivate behavior.
    @ViewBuilder
    private func activeTabRow(_ tab: CarPlayTab) -> some View {
        if let folderId = tab.folderId {
            NavigationLink {
                CarPlayFolderDetailView(folderId: folderId, viewModel: viewModel)
            } label: {
                HStack {
                    Text(viewModel.config.name(for: tab))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemSymbol: .line3Horizontal)
                        .foregroundStyle(.gray)
                }
            }
        } else {
            Button {
                viewModel.updateTab(tab, active: false)
            } label: {
                HStack {
                    Text(viewModel.config.name(for: tab))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemSymbol: .line3Horizontal)
                        .foregroundStyle(.gray)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var addTabButton: some View {
        Button {
            newTabName = ""
            showAddTabSheet = true
        } label: {
            Label(L10n.CarPlay.Config.Tabs.Add.title, systemSymbol: .plus)
        }
    }

    /// Presented to the user as creating a tab; behind the scenes it creates a folder that lives
    /// outside of Quick Access and immediately backs the new tab.
    @ViewBuilder
    private var addTabSheet: some View {
        NavigationStack {
            Form {
                Section(L10n.CarPlay.Config.Tabs.Name.title) {
                    TextField(L10n.CarPlay.Config.Tabs.Name.title, text: $newTabName)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(L10n.CarPlay.Config.Tabs.New.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { showAddTabSheet = false }) {
                        Text(L10n.cancelLabel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        let name = newTabName.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.addTabFolder(
                            named: name.isEmpty ? L10n.Watch.Configuration.Folder.defaultName : name
                        )
                        showAddTabSheet = false
                    }) {
                        Text(L10n.CarPlay.Config.Tabs.Add.title)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// Built-in tabs not yet active, followed by Quick Access folders not yet promoted to a tab.
    /// Tab-only folders never show here: they are deleted together with their tab.
    private var inactiveTabs: [CarPlayTab] {
        let standardTabs = CarPlayTab.allCases.filter { tab in
            !viewModel.config.tabs.contains(tab)
        }
        let folderTabs = viewModel.config.folders
            .map { CarPlayTab.folder(folderId: $0.id) }
            .filter { !viewModel.config.tabs.contains($0) }
        return standardTabs + folderTabs
    }
}

#Preview {
    CarPlayTabsSelectionView(viewModel: CarPlayConfigurationViewModel())
}
