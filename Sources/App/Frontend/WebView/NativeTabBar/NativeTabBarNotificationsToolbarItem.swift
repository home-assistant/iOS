import Shared
import SwiftUI

/// The notifications bell at the trailing end of a tab's bar, badged with the count in the frontend's accent colour.
@available(iOS 26, *)
struct NativeTabBarNotificationsToolbarItem: ToolbarContent {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
        static let badgeHeight = DesignSystem.Spaces.two
        static let badgeOffset = CGSize(width: DesignSystem.Spaces.one, height: -DesignSystem.Spaces.half)
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
                            if notifications.badge > 0 {
                                badge
                            }
                        }
                }
            }
            .accessibilityValue(notifications.badge > 0 ? badgeText : "")
        }
    }

    private var badgeText: String {
        NumberFormatter.localizedString(from: NSNumber(value: notifications.badge), number: .decimal)
    }

    private var badge: some View {
        Text(badgeText)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(badgeTextColor)
            .padding(.horizontal, DesignSystem.Spaces.half)
            .frame(minWidth: Constants.badgeHeight)
            .frame(height: Constants.badgeHeight)
            .fixedSize()
            .background(badgeColor, in: Capsule())
            .offset(x: Constants.badgeOffset.width, y: Constants.badgeOffset.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
