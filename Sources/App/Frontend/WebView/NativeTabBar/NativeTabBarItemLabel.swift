import HAKit
import Shared
import SwiftUI

/// A tab bar entry as a list row label: its Material icon (or the user's avatar for Profile) and title.
struct NativeTabBarItemLabel: View {
    private enum Constants {
        static let iconSize: CGFloat = 24
    }

    let item: NativeTabBarItem
    let server: Server
    let user: HAResponseCurrentUser?
    var accentColor: Color = .haPrimary

    var body: some View {
        Label {
            Text(item.title)
                .foregroundStyle(Color.primary)
        } icon: {
            if item.sidebarItem?.kind == .profile {
                MacSidebarAvatarView(
                    server: server,
                    title: item.title,
                    user: user,
                    size: Constants.iconSize,
                    accentColor: accentColor
                )
            } else {
                Image(uiImage: item.icon.image(
                    ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                    color: .label
                ))
                .renderingMode(.template)
                .foregroundStyle(accentColor)
            }
        }
    }
}

#Preview {
    List {
        NativeTabBarItemLabel(
            item: .init(kind: .panel(.init(
                id: "home",
                kind: .panel(path: "/home"),
                title: "Overview",
                icon: .material(.viewDashboardIcon)
            ))),
            server: ServerFixture.standard,
            user: nil
        )
        NativeTabBarItemLabel(item: .init(kind: .search), server: ServerFixture.standard, user: nil)
        NativeTabBarItemLabel(item: .init(kind: .assist), server: ServerFixture.standard, user: nil)
    }
}
