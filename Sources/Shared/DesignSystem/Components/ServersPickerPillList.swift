import SwiftUI

public struct ServersPickerPillList: View {
    @Binding private var selectedServerId: String?

    public init(selectedServerId: Binding<String?>) {
        self._selectedServerId = selectedServerId
    }

    public var body: some View {
        serversList
    }

    @ViewBuilder
    private var serversList: some View {
        if Current.servers.all.count > 1 {
            Section {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Current.servers.all.sorted(by: { lhs, rhs in
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
        }
    }
}

#Preview {
    List {
        ServersPickerPillList(selectedServerId: .constant("1"))
    }
}
