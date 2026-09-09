import HAKit
import Shared
import SwiftUI

/// A sidebar page as a list row label: its Material icon (or the user's avatar for Profile) and title.
struct NativeTabBarItemLabel: View {
    private enum Constants {
        static let iconSize: CGFloat = 24
    }

    let item: MacSidebarItem
    let server: Server
    let user: HAResponseCurrentUser?

    var body: some View {
        Label {
            Text(item.title)
                .foregroundStyle(Color.primary)
        } icon: {
            if item.kind == .profile {
                MacSidebarAvatarView(server: server, title: item.title, user: user, size: Constants.iconSize)
            } else {
                Image(uiImage: item.icon.image(
                    ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                    color: .label
                ))
                .renderingMode(.template)
                .foregroundStyle(Color.haPrimary)
            }
        }
    }
}

#Preview {
    List {
        NativeTabBarItemLabel(
            item: .init(
                id: "home",
                kind: .panel(path: "/home"),
                title: "Overview",
                icon: .material(.viewDashboardIcon)
            ),
            server: ServerFixture.standard,
            user: nil
        )
        NativeTabBarItemLabel(
            item: .init(id: "profile", kind: .profile, title: "Bruno", icon: .material(.accountIcon)),
            server: ServerFixture.standard,
            user: nil
        )
    }
}
