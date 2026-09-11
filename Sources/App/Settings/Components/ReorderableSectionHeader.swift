import Shared
import SwiftUI

/// Section header whose trailing link reveals the reorder handles of the rows it heads.
struct ReorderableSectionHeader: View {
    private let title: String?
    @Binding private var isEditing: Bool

    init(title: String? = nil, isEditing: Binding<Bool>) {
        self.title = title
        self._isEditing = isEditing
    }

    var body: some View {
        HStack {
            if let title {
                Text(title)
            }
            Spacer()
            Button {
                toggleEditing()
            } label: {
                Text(isEditing ? L10n.doneLabel : L10n.editLabel)
                    .textCase(nil)
            }
            .buttonStyle(.borderless)
        }
    }

    func toggleEditing() {
        withAnimation {
            isEditing.toggle()
        }
    }
}

#Preview {
    List {
        Section {
            Text(verbatim: "Kitchen light")
        } header: {
            ReorderableSectionHeader(title: "Items", isEditing: .constant(false))
        }
        Section {
            Text(verbatim: "Kitchen light")
        } header: {
            ReorderableSectionHeader(isEditing: .constant(true))
        }
    }
}
