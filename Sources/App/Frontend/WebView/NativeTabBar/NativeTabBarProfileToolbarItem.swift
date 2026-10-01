#if os(iOS)
import SFSafeSymbols
import Shared
import SwiftUI

/// The user's avatar in a tab's bar: the server picker when there are several servers, otherwise Profile.
@available(iOS 26, *)
struct NativeTabBarProfileToolbarItem: ToolbarContent {
    let viewModel: NativeTabBarViewModel
    let profile: MacSidebarItem
    let avatar: UIImage

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.hasMultipleServers {
                Menu {
                    NativeTabBarProfileMenuItems(viewModel: viewModel, profile: profile)
                } label: {
                    avatarLabel(viewModel.sidebar.server.info.name)
                }
            } else {
                Button {
                    viewModel.open(profile)
                } label: {
                    avatarLabel(profile.title)
                }
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
    }

    private func avatarLabel(_ title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: avatar)
                .renderingMode(.original)
        }
    }
}

@available(iOS 26, *)
#Preview {
    let viewModel = NativeTabBarViewModel.preview()
    NavigationStack {
        Color.clear
            .toolbar {
                if let profile = viewModel.profileItem {
                    NativeTabBarProfileToolbarItem(
                        viewModel: viewModel,
                        profile: profile,
                        avatar: NativeTabBarAvatarImage.circular(nil, initial: profile.title, size: 24)
                    )
                }
            }
    }
}
#endif
