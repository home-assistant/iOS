import HAKit
import Shared
import SwiftUI

struct HomeAssistantAccountRowView: View {
    private enum Constants {
        static let imageSize: CGFloat = 40
        static let compactImageSize: CGFloat = 32
        static let compactMinHeight: CGFloat = 48
    }

    let server: Server
    let isCompact: Bool

    @State private var serverName: String = ""
    @State private var userName: String = ""
    @State private var profilePicture: UIImage?
    @State private var serverObserver: HACancellable?

    init(server: Server, isCompact: Bool = false) {
        self.server = server
        self.isCompact = isCompact
    }

    private var imageSize: CGFloat {
        isCompact ? Constants.compactImageSize : Constants.imageSize
    }

    var body: some View {
        HStack {
            Group {
                if let profilePicture {
                    Image(uiImage: profilePicture)
                        .resizable()
                } else {
                    Circle()
                        .fill(.haPrimary)
                        .overlay(
                            Text(serverName.prefix(1).uppercased())
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: imageSize, height: imageSize)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(serverName)
                    .font(isCompact ? .body : .headline)
                    .lineLimit(1)
                Text(userName)
                    .font(isCompact ? .caption2 : .caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: isCompact ? Constants.compactMinHeight : nil)
        .onAppear {
            setupObserver()
            loadUserNameAndProfilePicture()
        }
        .onDisappear {
            serverObserver?.cancel()
        }
    }

    private func setupObserver() {
        // Set initial value
        serverName = server.info.name

        // Observe changes to server info
        serverObserver = server.observe { info in
            serverName = info.name
        }
    }

    private func loadUserNameAndProfilePicture() {
        guard let api = Current.api(for: server) else { return }

        // Shows something immediately, and still shows a picture when the server is unreachable.
        api.cachedProfilePicture { image in
            if profilePicture == nil {
                profilePicture = image
            }
        }

        api.currentUser { user in
            userName = user?.name ?? ""

            guard let user else { return }
            api.profilePicture(for: user) { image in
                profilePicture = image
            }
        }
    }
}
