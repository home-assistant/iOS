import HAKit
import Shared
import SwiftUI

struct HomeAssistantAccountRowView: View {
    let server: Server

    @State private var serverName: String = ""
    @State private var userName: String = ""
    @State private var profilePictureURL: URL?
    @State private var serverObserver: HACancellable?

    private var imageSize: CGFloat = 40

    init(server: Server) {
        self.server = server
    }

    var body: some View {
        HStack {
            AsyncImage(url: profilePictureURL) { image in
                image
                    .resizable()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(.haPrimary)
                    .frame(width: imageSize, height: imageSize)
                    .overlay(
                        Text(serverName.prefix(1).uppercased())
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading) {
                Text(serverName)
                    .font(.headline)
                Text(userName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
        Current.api(for: server)?.connection.caches.user.once { user in
            userName = user.name.orEmpty
        }

        Current.api(for: server)?.profilePictureURL { url in
            profilePictureURL = url
        }
    }
}
