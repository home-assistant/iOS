import SFSafeSymbols
import Shared
import SwiftUI

/// The More tab: a profile / notifications / settings header (the profile doubles as a server picker when
/// there is more than one server), the sidebar pages that are not in the bar, and the button that
/// customises the bar.
@available(iOS 26, *)
struct NativeTabBarMoreView: View {
    private enum Constants {
        static let avatarSize: CGFloat = 44
        static let headerIconSize: CGFloat = 40
        static let badgeMinWidth: CGFloat = 18
        static let badgeOffset: CGFloat = 6
    }

    private static let customizeTransitionID = "customizeTabs"

    @ObservedObject var viewModel: NativeTabBarViewModel
    @State private var showsCustomize = false
    @Namespace private var customizeNamespace

    var body: some View {
        List {
            Section {
                HStack(spacing: DesignSystem.Spaces.two) {
                    if let profile = viewModel.profileItem {
                        let header = HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                            MacSidebarAvatarView(
                                server: viewModel.sidebar.server,
                                title: profile.title,
                                user: viewModel.sidebar.user,
                                size: Constants.avatarSize
                            )
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                                Text(profile.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.primary)
                                Text(viewModel.sidebar.server.info.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                            .lineLimit(1)
                            if viewModel.hasMultipleServers {
                                Image(systemSymbol: .chevronUpChevronDown)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        if viewModel.hasMultipleServers {
                            Menu {
                                Picker(L10n.ServersSelection.title, selection: Binding(
                                    get: { viewModel.sidebar.server.identifier },
                                    set: { viewModel.open(serverIdentifier: $0) }
                                )) {
                                    ForEach(viewModel.servers, id: \.identifier) { server in
                                        Text(server.info.name).tag(server.identifier)
                                    }
                                }
                                .pickerStyle(.inline)
                                Divider()
                                Button {
                                    viewModel.open(profile)
                                } label: {
                                    Label(FrontendStrings.panelProfile, systemSymbol: .personCropCircle)
                                }
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
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer(minLength: 0)
                    if let notifications = viewModel.notificationsItem {
                        Button {
                            viewModel.open(notifications)
                        } label: {
                            Image(systemSymbol: .bell)
                                .font(.title3)
                                .foregroundStyle(Color.primary)
                                .frame(width: Constants.headerIconSize, height: Constants.headerIconSize)
                                .background(Circle().fill(Color(uiColor: .tertiarySystemFill)))
                                .overlay(alignment: .topTrailing) {
                                    if notifications.badge > 0 {
                                        Text(notifications.badge, format: .number)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, DesignSystem.Spaces.half)
                                            .frame(
                                                minWidth: Constants.badgeMinWidth,
                                                minHeight: Constants.badgeMinWidth
                                            )
                                            .background(Capsule().fill(Color.red))
                                            .offset(x: Constants.badgeOffset, y: -Constants.badgeOffset)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(notifications.title)
                    }
                    Menu {
                        if let settings = viewModel.settingsItem {
                            Button {
                                viewModel.open(settings)
                            } label: {
                                Label(L10n.TabBar.More.homeAssistantSettings, systemSymbol: .gearshape)
                            }
                        }
                        Button {
                            viewModel.showAppSettings()
                        } label: {
                            Label(L10n.TabBar.More.appSettings, systemSymbol: .iphone)
                        }
                    } label: {
                        Image(systemSymbol: .gearshape)
                            .font(.title3)
                            .foregroundStyle(Color.primary)
                            .frame(width: Constants.headerIconSize, height: Constants.headerIconSize)
                            .background(Circle().fill(Color(uiColor: .tertiarySystemFill)))
                    }
                    .accessibilityLabel(L10n.Mac.Sidebar.settings)
                }
                .padding(.vertical, DesignSystem.Spaces.half)
            }
            if !viewModel.moreItems.isEmpty {
                Section {
                    ForEach(viewModel.moreItems) { item in
                        Button {
                            viewModel.open(item)
                        } label: {
                            NativeTabBarItemLabel(
                                item: item,
                                server: viewModel.sidebar.server,
                                user: viewModel.sidebar.user
                            )
                        }
                    }
                }
            }
            Section {
                Button {
                    showsCustomize = true
                } label: {
                    Label(L10n.TabBar.Customize.title, systemSymbol: .squareGrid2x2)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                        .padding(.vertical, DesignSystem.Spaces.one)
                        .background(Capsule().fill(Color(uiColor: .secondarySystemFill)))
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: Self.customizeTransitionID, in: customizeNamespace)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            .listSectionSpacing(DesignSystem.Spaces.two)
        }
        .sheet(isPresented: $showsCustomize) {
            NavigationStack {
                NativeTabBarCustomizeView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            CloseButton {
                                showsCustomize = false
                            }
                        }
                    }
            }
            .navigationTransition(.zoom(sourceID: Self.customizeTransitionID, in: customizeNamespace))
        }
        .navigationTitle(L10n.TabBar.More.title)
    }
}

@available(iOS 26, *)
#Preview {
    NavigationStack {
        NativeTabBarMoreView(viewModel: .preview())
    }
}
