import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeSectionsReorderView: View {
    let sections: [(id: String, name: String)]
    @Binding var sectionOrder: [String]
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(currentOrderedSections(), id: \.id) { item in
                    Text(item.name)
                }
                .onMove(perform: move)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(L10n.HomeSectionsReorderView.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.HomeSectionsReorderView.done) {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
    }

    private func currentOrderedSections() -> [(id: String, name: String)] {
        let nameById = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0.name) })
        // Build ordered list using sectionOrder first, then any new ids
        let orderedIds = sectionOrder + sections.map(\.id).filter { !sectionOrder.contains($0) }
        return orderedIds.compactMap { id in
            guard let name = nameById[id] else { return nil }
            return (id: id, name: name)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = currentOrderedSections()
        items.move(fromOffsets: source, toOffset: destination)
        sectionOrder = items.map(\.id)
    }
}
