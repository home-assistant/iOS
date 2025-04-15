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
                        ServerSelectViewRow(
                            name: server.info.name,
                            userName: "Unknown",
                            selected: false
                        ) {
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
                        SettingsButton(tint: Color(uiColor: Asset.Colors.haPrimary.color)) {
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
    let name: String
    let userName: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }, label: {
            HStack(spacing: Spaces.two) {
                profilePicture
                VStack {
                    Group {
                        Text(name)
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
        .tint(Color.asset(Asset.Colors.haPrimary))
    }

    private var profilePicture: some View {
        ZStack {
            Image(systemSymbol: .circleFill)
                .resizable()
                .frame(width: 40, height: 40)
            Text(String(userName.first ?? Character("")))
                .foregroundStyle(.white)
                .font(.body.bold())
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
        ServerSelectViewRow(
            name: "Home", userName: "Bruno", selected: false
        ) {}
        ServerSelectViewRow(
            name: "Family", userName: "Andrea", selected: true
        ) {}
        ServerSelectViewRow(
            name: "Vacation home", userName: "Sonia", selected: false
        ) {}
    }
}
