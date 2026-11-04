import Shared
import SwiftUI

/// A pinned page's tab: the frontend, with the avatar and bell in the bar beside it wherever the bars run vertically.
@available(iOS 26, *)
struct NativeTabBarFrontendTabView: View {
    @ObservedObject var viewModel: NativeTabBarViewModel
    let item: NativeTabBarItem
    let webViewController: WebViewController?
    let frontendOpacity: Double
    let frontendIgnoredSafeAreaEdges: Edge.Set
    let showsBarItems: Bool
    let avatar: UIImage
    let onNeedsWebViewController: () -> Void

    var body: some View {
        ZStack {
            if showsBarItems {
                NavigationStack {
                    Color.clear
                        .toolbar {
                            if let profile = viewModel.profileItem {
                                NativeTabBarProfileToolbarItem(viewModel: viewModel, profile: profile, avatar: avatar)
                            }
                            if let notifications = viewModel.notificationsItem {
                                NativeTabBarNotificationsToolbarItem(viewModel: viewModel, notifications: notifications)
                            }
                        }
                        .toolbarBackground(.hidden, for: .navigationBar)
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
        avatar: NativeTabBarAvatarImage.circular(nil, initial: "B", size: NativeTabBarAvatarImage.barButtonSize),
        onNeedsWebViewController: {}
    )
}
