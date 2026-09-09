import SFSafeSymbols
import Shared
import SwiftUI

/// The More tab: the rest of the list under a bar with the profile picker, notifications and settings.
@available(iOS 26, *)
struct NativeTabBarMoreView: View {
    private enum Constants {
        static let avatarSize: CGFloat = 28
        static let badgeMinWidth: CGFloat = 18
        static let badgeOffset: CGFloat = 6
    }

    private static let customizeTransitionID = "customizeTabs"

    @ObservedObject var viewModel: NativeTabBarViewModel
    @State private var showsCustomize = false
    @State private var rowFrames: [String: CGRect] = [:]
    @Namespace private var customizeNamespace
    @Environment(\.serverSelectionNamespace) private var settingsTransitionNamespace

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
                                user: viewModel.sidebar.user
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
                    showsCustomize = true
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
                .matchedTransitionSource(id: Self.customizeTransitionID, in: customizeNamespace)
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
                            size: Constants.avatarSize
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
                    }
                }
            }
            if let notifications = viewModel.notificationsItem {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.open(notifications)
                    } label: {
                        Image(systemSymbol: .bell)
                            .overlay(alignment: .topTrailing) {
                                if notifications.badge > 0 {
                                    Text(notifications.badge, format: .number)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, DesignSystem.Spaces.half)
                                        .frame(minWidth: Constants.badgeMinWidth, minHeight: Constants.badgeMinWidth)
                                        .background(Capsule().fill(Color.red))
                                        .offset(x: Constants.badgeOffset, y: -Constants.badgeOffset)
                                }
                            }
                    }
                    .accessibilityLabel(notifications.title)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
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
                }
                .accessibilityLabel(L10n.Mac.Sidebar.settings)
                .modify { view in
                    if let settingsTransitionNamespace {
                        view.matchedTransitionSource(
                            id: NativeTabBarViewModel.appSettingsTransitionID,
                            in: settingsTransitionNamespace
                        )
                    } else {
                        view
                    }
                }
            }
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
    }
}

@available(iOS 26, *)
#Preview {
    NavigationStack {
        NativeTabBarMoreView(viewModel: .preview())
    }
}
