import Shared
import SwiftUI

struct ServerSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSheet = true

    let prompt: String?
    let includeSettings: Bool
    let selectAction: (Server) -> Void

    var body: some View {
        VStack {}
            .background(Color.clear)
            .sheet(isPresented: $showSheet) {
                if #available(iOS 16.0, *) {
                    content
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.hidden)
                } else {
                    content
                }
            }
            .onChange(of: showSheet) { newValue in
                if !newValue {
                    dismiss()
                }
            }
    }

    private var content: some View {
        NavigationView {
            List {
                if let prompt {
                    Section {
                        Text(prompt)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal)
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
            .navigationViewStyle(.stack)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.ServersSelection.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        showSheet = false
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if includeSettings {
                        SettingsButton(tint: Color.haPrimary) {
                            dismiss()
                            Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
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
    @State private var profilePictureURL: URL?
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
                Image(systemSymbol: selected ? .checkmarkCircleFill : .circle)
            }
        })
        .tint(Color.haPrimary)
        .onAppear {
            updateSelectionIndicator()
            loadUserNameAndProfilePicture()
        }
    }

    private var profilePicture: some View {
        AsyncImage(url: profilePictureURL) { image in
            image
                .resizable()
        } placeholder: {
            ZStack {
                Image(systemSymbol: .circleFill)
                    .resizable()
                Text(String(userName.first ?? Character(" ")))
                    .foregroundStyle(.white)
                    .font(.body.bold())
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.haPrimary, lineWidth: 2)
        )
    }

    private func updateSelectionIndicator() {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise).done { controller in
            selected = controller.server == server
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
