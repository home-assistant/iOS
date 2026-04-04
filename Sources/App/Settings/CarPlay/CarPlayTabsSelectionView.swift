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
                            Text(tab.name)
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
                Text(L10n.CarPlay.Tabs.Active.DeleteAction.title)
            }
            if viewModel.config.tabs.count != CarPlayTab.allCases.count {
                Section(L10n.CarPlay.Tabs.Inactive.title) {
                    ForEach(CarPlayTab.allCases.filter({ tab in
                        !viewModel.config.tabs.contains(tab)
                    }), id: \.rawValue) { tab in
                        Button {
                            viewModel.updateTab(tab, active: true)
                        } label: {
                            HStack {
                                Text(tab.name)
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
}

#Preview {
    CarPlayTabsSelectionView(viewModel: CarPlayConfigurationViewModel())
}
