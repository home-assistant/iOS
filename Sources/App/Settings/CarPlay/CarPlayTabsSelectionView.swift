import CarPlay
import SFSafeSymbols
import Shared
import SwiftUI

struct CarPlayTabsSelectionView: View {
    @ObservedObject var viewModel: CarPlayConfigurationViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.config.tabs, id: \.rawValue) { tab in
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
                .onMove { indices, newOffset in
                    viewModel.moveTab(from: indices, to: newOffset)
                }
                .onDelete { indexSet in
                    viewModel.deleteTab(at: indexSet)
                }
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
    }

    /// Built-in tabs not yet active, followed by Quick Access folders not yet promoted to a tab.
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
