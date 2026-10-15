import Shared
import SwiftUI

/// The pencil in the server details toolbar: a menu listing what the screen can edit.
struct ServerEditMenu: View {
    let onEdit: (ServerDetailsRowView.EditOption) -> Void

    var body: some View {
        Menu {
            ForEach(ServerDetailsRowView.EditOption.allCases, id: \.self) { option in
                Button {
                    onEdit(option)
                } label: {
                    Label(option.title, systemSymbol: option.symbol)
                }
            }
        } label: {
            Image(systemSymbol: .pencil)
        }
        .tint(.haPrimary)
        .accessibilityLabel(L10n.editLabel)
    }
}

#Preview {
    ServerEditMenu { _ in }
}
