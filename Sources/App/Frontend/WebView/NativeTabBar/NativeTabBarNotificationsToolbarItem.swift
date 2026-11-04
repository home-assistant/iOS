import Shared
import SwiftUI

/// The notifications bell at the trailing end of a tab's bar, badged with the count in the frontend's accent colour.
@available(iOS 26, *)
struct NativeTabBarNotificationsToolbarItem: ToolbarContent {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }

    let viewModel: NativeTabBarViewModel
    let notifications: MacSidebarItem
    let badgeColor: Color
    let badgeTextColor: Color

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
                        .overlay(alignment: .topTrailing) {
                            NativeTabBarNotificationsBadge(
                                count: notifications.badge,
                                color: badgeColor,
                                textColor: badgeTextColor
                            )
                        }
                }
            }
            .accessibilityValue(NativeTabBarNotificationsBadge.text(for: notifications.badge))
        }
    }
}

@available(iOS 26, *)
#Preview {
    let viewModel = NativeTabBarViewModel.preview()
    let notifications = viewModel.notificationsItem.map { with($0) { $0.badge = 3 } }
    NavigationStack {
        Color.clear
            .toolbar {
                if let notifications {
                    NativeTabBarNotificationsToolbarItem(
                        viewModel: viewModel,
                        notifications: notifications,
                        badgeColor: viewModel.badgeColor,
                        badgeTextColor: viewModel.badgeTextColor
                    )
                }
            }
    }
}
