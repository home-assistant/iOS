#if os(iOS)
import SFSafeSymbols
import Shared
import SwiftUI

/// The More tab: the rest of the list under a bar with the profile picker, notifications and settings.
@available(iOS 26, *)
struct NativeTabBarMoreView: View {
    private enum Constants {
        static let avatarSize: CGFloat = 28
    }

    @ObservedObject var viewModel: NativeTabBarViewModel
    @State private var rowFrames: [String: CGRect] = [:]
    @Environment(\.serverSelectionNamespace) private var transitionNamespace
    @Environment(\.appSettingsPresenter) private var appSettingsPresenter

    var body: some View {
        List {
            if !viewModel.moreItems.isEmpty {
                Section {
                    ForEach(viewModel.moreItems) { item in
                        Button {
                            viewModel.open(item, sourceFrame: rowFrames[item.id])
                        } label: {
                            NativeTabBarItemLabel(
                                item: item,
                                server: viewModel.sidebar.server,
                                user: viewModel.sidebar.user,
                                accentColor: viewModel.accentColor
                            )
                        }
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { frame in
                            rowFrames[item.id] = frame
                        }
                    }
                } header: {
                    Text(L10n.TabBar.Customize.DashboardsSection.header)
                }
            }
            Section {
                Button {
                    viewModel.showCustomize(zoomingFromButton: true)
                } label: {
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: .pencil)
                        Text(L10n.TabBar.More.customize)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                    .padding(.vertical, DesignSystem.Spaces.one)
                    .background(Capsule().fill(Color(uiColor: .secondarySystemFill)))
                }
                .buttonStyle(.plain)
                .modify { view in
                    if let transitionNamespace {
                        view.matchedTransitionSource(
                            id: NativeTabBarViewModel.customizeTransitionID,
                            in: transitionNamespace
                        )
                    } else {
                        view
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            .listSectionSpacing(DesignSystem.Spaces.two)
        }
        .contentMargins(.top, DesignSystem.Spaces.two, for: .scrollContent)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let profile = viewModel.profileItem {
                    let header = HStack(spacing: DesignSystem.Spaces.one) {
                        MacSidebarAvatarView(
                            server: viewModel.sidebar.server,
                            title: profile.title,
                            user: viewModel.sidebar.user,
                            size: Constants.avatarSize,
                            accentColor: viewModel.accentColor
                        )
                        Text(viewModel.sidebar.server.info.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        if viewModel.hasMultipleServers {
                            Image(systemSymbol: .chevronUpChevronDown)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    if viewModel.hasMultipleServers {
                        Menu {
                            NativeTabBarProfileMenuItems(viewModel: viewModel, profile: profile)
                        } label: {
                            header
                        }
                        .accessibilityLabel(L10n.ServersSelection.title)
                    } else {
                        Button {
                            viewModel.open(profile)
                        } label: {
                            header
                        }
                    }
                }
            }
            if let notifications = viewModel.notificationsItem {
                NativeTabBarNotificationsToolbarItem(viewModel: viewModel, notifications: notifications)
            }
            NativeTabBarSettingsToolbarItem(
                viewModel: viewModel,
                appSettingsTransitionID: NativeTabBarViewModel.appSettingsTransitionID,
                transitionNamespace: transitionNamespace,
                appSettingsPresenter: appSettingsPresenter
            )
        }
    }
}

@available(iOS 26, *)
#Preview {
    NavigationStack {
        NativeTabBarMoreView(viewModel: .preview())
    }
}
#endif
