import SFSafeSymbols
import Shared
import SwiftUI

/// The More tab: the rest of the list under a bar with the profile picker, notifications and settings. Where the
/// bars run vertically the avatar moves into the bar beside the gear, which gives way to the bell once a page
/// from the list is showing.
@available(iOS 26, *)
struct NativeTabBarMoreView: View {
    private enum Constants {
        static let avatarSize: CGFloat = 28
    }

    @ObservedObject var viewModel: NativeTabBarViewModel
    var usesVerticalBar = false
    var avatar: UIImage?
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
            if usesVerticalBar {
                if let profile = viewModel.profileItem {
                    NativeTabBarProfileToolbarItem(
                        viewModel: viewModel,
                        profile: profile,
                        avatar: avatar ?? NativeTabBarAvatarImage.circular(
                            nil,
                            initial: profile.title,
                            size: NativeTabBarAvatarImage.barButtonSize
                        )
                    )
                }
                // Once a page from the list is up, the bar is any page's bar: the bell takes the gear's place.
                if viewModel.moreShowsFrontend {
                    if let notifications = viewModel.notificationsItem {
                        NativeTabBarNotificationsToolbarItem(viewModel: viewModel, notifications: notifications)
                    }
                } else {
                    settingsToolbarItem
                }
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    profileHeader
                }
                if let notifications = viewModel.notificationsItem {
                    NativeTabBarNotificationsToolbarItem(viewModel: viewModel, notifications: notifications)
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                settingsToolbarItem
            }
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        NativeTabBarSettingsToolbarItem(
            viewModel: viewModel,
            appSettingsTransitionID: NativeTabBarViewModel.appSettingsTransitionID,
            transitionNamespace: transitionNamespace,
            appSettingsPresenter: appSettingsPresenter
        )
    }

    /// The avatar beside the server's name: the server picker when there are several servers, otherwise Profile.
    @ViewBuilder
    private var profileHeader: some View {
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
}

@available(iOS 26, *)
#Preview {
    NavigationStack {
        NativeTabBarMoreView(viewModel: .preview())
    }
}

@available(iOS 26, *)
#Preview("Vertical bar") {
    NavigationStack {
        NativeTabBarMoreView(viewModel: .preview(), usesVerticalBar: true)
    }
}
