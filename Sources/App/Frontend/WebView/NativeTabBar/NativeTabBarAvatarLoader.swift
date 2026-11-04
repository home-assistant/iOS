import Shared
import SwiftUI

/// Loads the user's profile picture as a round bar button image for the bars that show it, and hands its
/// content the picture, or the user's initial until it arrives.
@available(iOS 26, *)
struct NativeTabBarAvatarLoader<Content: View>: View {
    @ObservedObject var viewModel: NativeTabBarViewModel
    /// The bars only show the avatar in a vertical column, so the picture is not fetched until then.
    let isActive: Bool
    @ViewBuilder let content: (UIImage) -> Content

    @State private var avatar: UIImage?

    var body: some View {
        content(avatar ?? placeholder)
            .onAppear { loadProfilePicture() }
            .onChange(of: isActive) { loadProfilePicture() }
            .onChange(of: viewModel.sidebar.user?.id) { loadProfilePicture() }
            // The picture can change in the frontend's profile page; coming back to a tab picks that up.
            .onChange(of: viewModel.selection) { loadProfilePicture() }
    }

    private var placeholder: UIImage {
        NativeTabBarAvatarImage.circular(nil, initial: initial, size: NativeTabBarAvatarImage.barButtonSize)
    }

    private var initial: String {
        viewModel.profileItem?.title ?? ""
    }

    private func loadProfilePicture() {
        guard isActive, let api = Current.api(for: viewModel.sidebar.server) else { return }
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
            initial: initial,
            size: NativeTabBarAvatarImage.barButtonSize
        )
    }
}

@available(iOS 26, *)
#Preview {
    NativeTabBarAvatarLoader(viewModel: .preview(), isActive: true) { avatar in
        Image(uiImage: avatar)
    }
}
