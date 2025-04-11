import SwiftUI

protocol ListPickerSelectable: Identifiable {
    var id: String { get }
    var text: String { get }
}

struct ListPickerContent {
    let sections: [Section]

    struct Section {
        let id: String
        let title: String
        let items: [Item]
    }

    struct Item {
        let id: String
        let title: String
    }
}

struct ListPicker: View {
    let title: String
    @Binding var selection: ListPickerContent.Item
    let content: ListPickerContent

    var body: some View {
        NavigationLink {
            ListPickerContentView(selection: $selection, content: content)
        } label: {
            HStack {
                Text(title)
                Text(selection.title)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundColor(Color(uiColor: .secondaryLabel))
            }
        }
    }
}

struct ListPickerContentView: View {
    @Binding var selection: ListPickerContent.Item
    let content: ListPickerContent

    var body: some View {
        List {
            ForEach(content.sections, id: \.id) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.id) { item in
                        Button {
                            selection = item
                        } label: {
                            HStack {
                                Text(item.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if selection.id == item.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("List picker") {
    ListPickerPreview.standard
}

#Preview("List picker content") {
    ListPickerPreview.content
}

enum ListPickerPreview {
    static var standard: some View {
        NavigationView {
            List {
                ListPicker(
                    title: "Select Item",
                    selection: .constant(.init(id: "2", title: "aaaa")),
                    content: .init(sections: [
                        .init(id: "1", title: "Section 1", items: [
                            .init(id: "1", title: "Abc"),
                            .init(id: "2", title: "aaaa"),
                            .init(id: "3", title: "bbbb"),
                            .init(id: "4", title: "ccccc"),
                        ]),
                        .init(id: "2", title: "Section 2", items: [
                            .init(id: "5", title: "Abc"),
                            .init(id: "6", title: "aaaa"),
                            .init(id: "7", title: "bbbb"),
                            .init(id: "8", title: "ccccc"),
                        ]),
                    ])
                )
            }
        }
    }

    static var content: some View {
        ListPickerContentView(
            selection: .constant(.init(id: "2", title: "aaaa")),
            content: .init(sections: [
                .init(id: "1", title: "Section 1", items: [
                    .init(id: "1", title: "Abc"),
                    .init(id: "2", title: "aaaa"),
                    .init(id: "3", title: "bbbb"),
                    .init(id: "4", title: "ccccc"),
                ]),
                .init(id: "2", title: "Section 2", items: [
                    .init(id: "5", title: "Abc"),
                    .init(id: "6", title: "aaaa"),
                    .init(id: "7", title: "bbbb"),
                    .init(id: "8", title: "ccccc"),
                ]),
            ])
        )
    }
}
