import SFSafeSymbols
import Shared
import SwiftUI

/// Picks which sidebar pages sit in the tab bar: the pinned pages, reorderable, over the pages left
/// to add. The bar holds `NativeTabBarConfigurationStore.maximumTabs` pages at most.
struct NativeTabBarCustomizeView: View {
    @ObservedObject var viewModel: NativeTabBarViewModel

    var body: some View {
        List {
            Section {
                if viewModel.tabItems.isEmpty {
                    Text(L10n.TabBar.Customize.TabsSection.empty)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.tabItems) { item in
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Button {
                            viewModel.removeTab(item)
                        } label: {
                            Image(systemSymbol: .minusCircleFill)
                                .font(.title3)
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.TabBar.Customize.remove)
                        NativeTabBarItemLabel(
                            item: item,
                            server: viewModel.sidebar.server,
                            user: viewModel.sidebar.user
                        )
                    }
                }
                .onMove { source, destination in
                    viewModel.moveTabs(fromOffsets: source, toOffset: destination)
                }
            } header: {
                Text(L10n.TabBar.Customize.TabsSection.header)
            } footer: {
                Text(L10n.TabBar.Customize.TabsSection.footer)
            }

            Section {
                ForEach(viewModel.pinnableItems.filter { !viewModel.isTab($0) }) { item in
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Button {
                            viewModel.addTab(item)
                        } label: {
                            Image(systemSymbol: .plusCircleFill)
                                .font(.title3)
                                .foregroundStyle(viewModel.canAddTab ? Color.green : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canAddTab)
                        .accessibilityLabel(L10n.TabBar.Customize.add)
                        NativeTabBarItemLabel(
                            item: item,
                            server: viewModel.sidebar.server,
                            user: viewModel.sidebar.user
                        )
                    }
                }
            } header: {
                Text(L10n.TabBar.Customize.AvailableSection.header)
            } footer: {
                if !viewModel.canAddTab {
                    Text(L10n.TabBar.Customize.AvailableSection.footerFull)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.tabItems.map(\.id))
        .navigationTitle(L10n.TabBar.Customize.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NativeTabBarCustomizeView(viewModel: .preview())
    }
}
