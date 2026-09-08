import SFSafeSymbols
import Shared
import SwiftUI

/// Picks which sidebar pages sit in the tab bar: the pinned pages, reorderable, over the pages listed in
/// More and the pages the user hid. The bar holds `NativeTabBarConfigurationStore.maximumTabs` pages at most.
struct NativeTabBarCustomizeView: View {
    private enum Constants {
        static let hiddenRowOpacity: Double = 0.6
    }

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

            if !moreItems.isEmpty {
                Section {
                    ForEach(moreItems) { item in
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
                            if viewModel.canHide(item) {
                                Spacer(minLength: 0)
                                Button(L10n.TabBar.Customize.hide) {
                                    viewModel.hide(item)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.small)
                                .font(.subheadline.weight(.medium))
                                .tint(Color.haPrimary)
                            }
                        }
                    }
                } header: {
                    Text(L10n.TabBar.Customize.MoreSection.header)
                } footer: {
                    Text(
                        viewModel.canAddTab
                            ? L10n.TabBar.Customize.MoreSection.footer
                            : L10n.TabBar.Customize.MoreSection.footerFull
                    )
                }
            }

            if !viewModel.hiddenItems.isEmpty {
                Section {
                    ForEach(viewModel.hiddenItems) { item in
                        HStack(spacing: DesignSystem.Spaces.one) {
                            NativeTabBarItemLabel(
                                item: item,
                                server: viewModel.sidebar.server,
                                user: viewModel.sidebar.user
                            )
                            .opacity(Constants.hiddenRowOpacity)
                            Spacer(minLength: 0)
                            Button(L10n.TabBar.Customize.show) {
                                viewModel.show(item)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                            .font(.subheadline.weight(.medium))
                            .tint(Color.haPrimary)
                        }
                    }
                } header: {
                    Text(L10n.TabBar.Customize.HiddenSection.header)
                } footer: {
                    Text(L10n.TabBar.Customize.HiddenSection.footer)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .animation(DesignSystem.Animation.easeInOutFaster, value: animationValue)
        .navigationTitle(L10n.TabBar.Customize.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var moreItems: [MacSidebarItem] {
        viewModel.pinnableItems.filter { !viewModel.isTab($0) }
    }

    private var animationValue: [String] {
        viewModel.tabItems.map(\.id) + viewModel.hiddenItems.map(\.id)
    }
}

#Preview {
    NavigationStack {
        NativeTabBarCustomizeView(viewModel: .preview(hiddenPanelPaths: ["logbook"]))
    }
}
