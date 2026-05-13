import Shared
import SwiftUI

struct AllowedTagsView: View {
    @State private var allowedTags: [AllowedTag] = []
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        List {
            Section {
                if allowedTags.isEmpty {
                    Text(L10n.Tags.Allowed.empty)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allowedTags, id: \.tag) { allowedTag in
                        Text(allowedTag.tag)
                            .font(.system(.body, design: .monospaced))
                    }
                    .onDelete(perform: deleteTags)
                }
            } footer: {
                Text(L10n.Tags.Allowed.footer)
            }
        }
        .navigationTitle(L10n.Tags.Allowed.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Tags.Allowed.deleteAll) {
                    showDeleteAllConfirmation = true
                }
                .disabled(allowedTags.isEmpty)
                .confirmationDialog(
                    L10n.Tags.Allowed.DeleteAll.Confirm.title,
                    isPresented: $showDeleteAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.cancelLabel, role: .cancel) {}
                    Button(L10n.Tags.Allowed.DeleteAll.Confirm.button, role: .destructive) {
                        AllowedTag.clearAll()
                        loadAllowedTags()
                    }
                }
            }
        }
        .onAppear(perform: loadAllowedTags)
    }

    private func loadAllowedTags() {
        allowedTags = AllowedTag.all()
    }

    private func deleteTags(at offsets: IndexSet) {
        offsets
            .map { allowedTags[$0].tag }
            .forEach(AllowedTag.delete)
        loadAllowedTags()
    }
}
