import Shared
import SwiftUI

/// The compact content of the Settings sheet: the servers, as buttons that activate them. It takes over the
/// sheet while it sits at the medium detent, and the toolbar's settings button expands the sheet back to
/// Settings.
struct ServerSelectionListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var observer = ServersObserver()
    @State private var activeServerIdentifier: Identifier<Server>?

    let prompt: ServerSelectPrompt?
    let selectAction: (Server) -> Void
    let expandAction: () -> Void

    var body: some View {
        NavigationView {
            List {
                if let prompt {
                    promptSection(prompt)
                }
                Section {
                    ForEach(observer.servers, id: \.identifier) { server in
                        serverButton(server)
                    }
                }
                .environment(\.defaultMinListRowHeight, 60)
            }
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.listSectionSpacing(DesignSystem.Spaces.one)
                } else {
                    view
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.ServersSelection.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    SettingsButton(tint: Color.haPrimary, action: expandAction)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: updateActiveServer)
    }

    private func promptSection(_ prompt: ServerSelectPrompt) -> some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                Text(prompt.message)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                if let link = prompt.link {
                    Text(link)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.vertical, DesignSystem.Spaces.one)
                        .padding(.horizontal, DesignSystem.Spaces.two)
                        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                }
            }
            .padding(.horizontal)
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }

    private func serverButton(_ server: Server) -> some View {
        Button {
            selectAction(server)
        } label: {
            HStack {
                HomeAssistantAccountRowView(server: server)
                Spacer()
                if server.identifier == activeServerIdentifier {
                    Image(systemSymbol: .checkmark)
                        .font(.body.bold())
                        .foregroundStyle(Color.haPrimary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func updateActiveServer() {
        Current.sceneManager.webViewControllerPromise.done { controller in
            activeServerIdentifier = controller.server.identifier
        }
    }
}

#Preview("Servers") {
    ServerSelectionListView(prompt: nil, selectAction: { _ in }, expandAction: {})
}

#Preview("Servers with prompt") {
    ServerSelectionListView(
        prompt: ServerSelectPrompt(
            message: L10n.Alerts.OpenUrlFromDeepLink.selectServer,
            link: "/?more-info-entity-id=light.living_room_lamp"
        ),
        selectAction: { _ in },
        expandAction: {}
    )
}
