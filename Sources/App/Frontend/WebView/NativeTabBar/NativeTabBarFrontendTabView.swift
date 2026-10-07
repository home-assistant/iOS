import Shared
import SwiftUI

/// A pinned page's tab: the frontend, with the avatar and bell in the bar beside it wherever the bars run vertically.
@available(iOS 26, *)
struct NativeTabBarFrontendTabView: View {
    private enum Constants {
        static let avatarSize: CGFloat = 32
    }

    @ObservedObject var viewModel: NativeTabBarViewModel
    let item: NativeTabBarItem
    let webViewController: WebViewController?
    let frontendOpacity: Double
    let frontendIgnoredSafeAreaEdges: Edge.Set
    let showsBarItems: Bool
    let onNeedsWebViewController: () -> Void

    @State private var avatar: UIImage?

    var body: some View {
        ZStack {
            if showsBarItems {
                NavigationStack {
                    Color.clear
                        .toolbar {
                            if let profile = viewModel.profileItem {
                                NativeTabBarProfileToolbarItem(
                                    viewModel: viewModel,
                                    profile: profile,
                                    avatar: avatar ?? NativeTabBarAvatarImage.circular(
                                        nil,
                                        initial: profile.title,
                                        size: Constants.avatarSize
                                    )
                                )
                            }
                            if let notifications = viewModel.notificationsItem {
                                NativeTabBarNotificationsToolbarItem(viewModel: viewModel, notifications: notifications)
                            }
                        }
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .onAppear { loadProfilePicture() }
                        .onChange(of: viewModel.sidebar.user?.id) { _ in loadProfilePicture() }
                }
            }
            NativeTabBarFrontendSlot(
                controller: webViewController,
                isActive: viewModel.selection == item.tab,
                onNeedsController: onNeedsWebViewController
            )
            .opacity(frontendOpacity)
            .ignoresSafeArea(edges: frontendIgnoredSafeAreaEdges)
        }
    }

    private func loadProfilePicture() {
        guard let api = Current.api(for: viewModel.sidebar.server) else { return }
        api.cachedProfilePicture { picture in
            if avatar == nil {
                updateAvatar(with: picture)
            }
        }
        guard let user = viewModel.sidebar.user else { return }
        api.profilePicture(for: user) { picture in
            updateAvatar(with: picture)
        }
    }

    private func updateAvatar(with picture: UIImage?) {
        avatar = NativeTabBarAvatarImage.circular(
            picture,
            initial: viewModel.profileItem?.title ?? "",
            size: Constants.avatarSize
        )
    }
}

@available(iOS 26, *)
#Preview {
    let viewModel = NativeTabBarViewModel.preview()
    NativeTabBarFrontendTabView(
        viewModel: viewModel,
        item: viewModel.tabItems[0],
        webViewController: nil,
        frontendOpacity: 1,
        frontendIgnoredSafeAreaEdges: .all,
        showsBarItems: true,
        onNeedsWebViewController: {}
    )
}
