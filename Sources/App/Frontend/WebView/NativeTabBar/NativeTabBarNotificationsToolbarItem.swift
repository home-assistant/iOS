import Shared
import SwiftUI

/// The notifications bell, badged with the unread count, at the trailing end of a tab's bar.
@available(iOS 26, *)
struct NativeTabBarNotificationsToolbarItem: ToolbarContent {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }

    let viewModel: NativeTabBarViewModel
    let notifications: MacSidebarItem

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.open(notifications)
            } label: {
                Label {
                    Text(notifications.title)
                } icon: {
                    Image(uiImage: notifications.icon.image(ofSize: Constants.iconSize, color: .label))
                        .renderingMode(.template)
                }
            }
            .badge(notifications.badge)
        }
    }
}

@available(iOS 26, *)
#Preview {
    let viewModel = NativeTabBarViewModel.preview()
    NavigationStack {
        Color.clear
            .toolbar {
                if let notifications = viewModel.notificationsItem {
                    NativeTabBarNotificationsToolbarItem(viewModel: viewModel, notifications: notifications)
                }
            }
    }
}
