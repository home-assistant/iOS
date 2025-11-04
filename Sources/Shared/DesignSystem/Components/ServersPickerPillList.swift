import SwiftUI

public struct ServersPickerPillList: View {
    @Binding private var selectedServerId: String?

    let servers: [Server]

    public init(servers: [Server] = Current.servers.all, selectedServerId: Binding<String?>) {
        self._selectedServerId = selectedServerId
        self.servers = servers
    }

    public var body: some View {
        serversList
    }

    @ViewBuilder
    private var serversList: some View {
        if servers.count > 1 {
            Section {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(servers.sorted(by: { lhs, rhs in
                            lhs.info.sortOrder < rhs.info.sortOrder
                        }), id: \.identifier) { server in
                            Button {
                                selectedServerId = server.identifier.rawValue
                            } label: {
                                PillView(
                                    text: server.info.name,
                                    selected: selectedServerId == server.identifier.rawValue
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.listSectionSpacing(DesignSystem.Spaces.half)
                } else {
                    view
                }
            }
        }
    }
}

#Preview {
    List {
        ServersPickerPillList(
            servers: [ServerFixture.standard, ServerFixture.withLessSecureAccess, ServerFixture.withRemoteConnection],
            selectedServerId: .constant("123")
        )

        Text("123")
    }
}
