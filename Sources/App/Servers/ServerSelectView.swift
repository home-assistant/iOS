import Shared
import SwiftUI

/// The server picker shown when an action (e.g. a server-less deep link, or the "show servers" gesture)
/// needs the user to choose a server. Presented as a sheet by `ContainerView`; dismisses via the SwiftUI
/// environment.
struct ServerSelectView: View {
    @Environment(\.dismiss) private var dismiss

    let prompt: String?
    let includeSettings: Bool
    let selectAction: (Server) -> Void

    var body: some View {
        NavigationView {
            List {
                if let prompt {
                    Section {
                        Text(prompt)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal)
                            .listRowBackground(Color.clear)
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                Section {
                    ForEach(Current.servers.all, id: \.identifier) { server in
                        ServerSelectViewRow(server: server) {
                            selectAction(server)
                            dismiss()
                        }
                    }
                }
            }
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.listSectionSpacing(DesignSystem.Spaces.one)
                } else {
                    view
                }
            }
            .navigationViewStyle(.stack)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.ServersSelection.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if includeSettings {
                        SettingsButton(tint: Color.haPrimary) {
                            dismiss()
                            Current.sceneManager.webViewControllerPromise
                                .done { controller in
                                    controller.showSettingsViewController()
                                }
                        }
                    }
                }
            }
        }
    }
}

struct ServerSelectViewRow: View {
    @State private var userName: String = ""
    @State private var profilePictureImage: UIImage?
    @State private var selected = false

    let server: Server
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }, label: {
            HStack(spacing: DesignSystem.Spaces.two) {
                profilePicture
                VStack {
                    Group {
                        Text(server.info.name)
                            .font(.headline)
                            .foregroundStyle(Color(uiColor: .label))
                        Text(userName)
                            .font(.caption)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                }
            }
        })
        .tint(Color.haPrimary)
        .onAppear {
            updateSelectionIndicator()
            loadUserNameAndProfilePicture()
        }
    }

    private var profilePicture: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let profilePictureImage {
                    Image(uiImage: profilePictureImage)
                        .resizable()
                } else {
                    ZStack {
                        Image(systemSymbol: .circleFill)
                            .resizable()
                        Text(String(userName.first ?? Character(" ")))
                            .foregroundStyle(.white)
                            .font(.body.bold())
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.haPrimary, lineWidth: 2)
            )
            if selected {
                Image(systemSymbol: .checkmarkCircleFill)
                    .foregroundStyle(.white, .haPrimary)
                    .offset(x: 5, y: 5)
            }
        }
    }

    private func updateSelectionIndicator() {
        Current.sceneManager.webViewControllerPromise.done { controller in
            selected = controller.server == server
        }
    }

    private func loadUserNameAndProfilePicture() {
        guard let api = Current.api(for: server) else { return }

        api.currentUser { user in
            userName = user?.name ?? ""

            guard let user else { return }
            api.profilePicture(for: user) { image in
                profilePictureImage = image
            }
        }
    }
}

#Preview("Servers") {
    ServerSelectView(prompt: nil, includeSettings: true) { _ in }
}

#Preview("Servers with prompt") {
    ServerSelectView(prompt: "Are you sure?", includeSettings: false) { _ in }
}

#Preview("Rows") {
    List {
        ServerSelectViewRow(server: ServerFixture.standard) {}
    }
}
