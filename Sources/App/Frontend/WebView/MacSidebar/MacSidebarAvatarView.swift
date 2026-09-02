import HAKit
import Shared
import SwiftUI

struct MacSidebarAvatarView: View {
    let server: Server
    let title: String
    let user: HAResponseCurrentUser?
    let size: CGFloat

    @State private var profilePicture: UIImage?

    var body: some View {
        Group {
            if let profilePicture {
                Image(uiImage: profilePicture)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.haPrimary)
                    .overlay(
                        Text(title.prefix(1).uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear { loadProfilePicture() }
        .onChange(of: user?.id) { _ in loadProfilePicture() }
    }

    private func loadProfilePicture() {
        guard let api = Current.api(for: server) else { return }
        api.cachedProfilePicture { image in
            if profilePicture == nil {
                profilePicture = image
            }
        }
        guard let user else { return }
        api.profilePicture(for: user) { image in
            profilePicture = image
        }
    }
}

#Preview {
    MacSidebarAvatarView(server: ServerFixture.standard, title: "Bruno", user: nil, size: 20)
}
