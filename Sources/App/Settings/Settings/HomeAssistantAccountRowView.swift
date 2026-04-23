import HAKit
import Shared
import SwiftUI

struct HomeAssistantAccountRowView: View {
    let server: Server

    @State private var serverName: String = ""
    @State private var userName: String = ""
    @State private var profilePicture: UIImage?
    @State private var serverObserver: HACancellable?

    private var imageSize: CGFloat = 40

    init(server: Server) {
        self.server = server
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
        guard let api = Current.api(for: server) else { return }

        api.currentUser { user in
            userName = user?.name.orEmpty ?? ""

            guard let user else { return }
            api.profilePicture(for: user) { image in
                profilePicture = image
            }
        }
    }
}
