import SFSafeSymbols
import Shared
import SwiftUI

/// Edits the list the tab bar is laid out from: the first `NativeTabBarViewModel.maximumTabs` entries are the
/// tabs, the rest fill More, and hidden entries wait at the bottom to be shown again.
struct NativeTabBarCustomizeView: View {
    private enum Constants {
        static let hiddenRowOpacity: Double = 0.6
    }

    @ObservedObject var viewModel: NativeTabBarViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.tabItems + viewModel.moreItems) { item in
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Button {
                            viewModel.hide(item)
                        } label: {
                            Image(systemSymbol: .minusCircleFill)
                                .font(.title3)
                                .foregroundStyle(viewModel.canHide(item) ? Color.red : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canHide(item))
                        .accessibilityLabel(L10n.TabBar.Customize.hide)
                        NativeTabBarItemLabel(
                            item: item,
                            server: viewModel.sidebar.server,
                            user: viewModel.sidebar.user
                        )
                        if let index = viewModel.tabItems.firstIndex(where: { $0.id == item.id }) {
                            Spacer(minLength: 0)
                            Text(L10n.TabBar.Customize.tabNumberD(index + 1))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.haPrimary)
                                .padding(.horizontal, DesignSystem.Spaces.one)
                                .padding(.vertical, DesignSystem.Spaces.micro)
                                .background(Capsule().fill(Color.haPrimaryLightFill))
                        }
                    }
                }
                .onMove { source, destination in
                    viewModel.moveItems(fromOffsets: source, toOffset: destination)
                }
            } header: {
                Text(L10n.TabBar.Customize.DashboardsSection.header)
            } footer: {
                Text(L10n.TabBar.Customize.DashboardsSection.footerFourTabs)
            }

            if !viewModel.hiddenItems.isEmpty {
                Section {
                    ForEach(viewModel.hiddenItems) { item in
                        HStack(spacing: DesignSystem.Spaces.one) {
                            Button {
                                viewModel.show(item)
                            } label: {
                                Image(systemSymbol: .plusCircleFill)
                                    .font(.title3)
                                    .foregroundStyle(Color.green)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.TabBar.Customize.show)
                            NativeTabBarItemLabel(
                                item: item,
                                server: viewModel.sidebar.server,
                                user: viewModel.sidebar.user
                            )
                            .opacity(Constants.hiddenRowOpacity)
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
        .animation(
            DesignSystem.Animation.easeInOutFaster,
            value: viewModel.tabItems.map(\.id) + viewModel.moreItems.map(\.id) + viewModel.hiddenItems.map(\.id)
        )
        .navigationTitle(L10n.TabBar.Customize.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NativeTabBarCustomizeView(viewModel: .preview(hiddenPanelPaths: ["logbook"]))
    }
}
