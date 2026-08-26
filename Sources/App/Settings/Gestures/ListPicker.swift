import SFSafeSymbols
import Shared
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
        let subtitle: String?
        let icon: SFSymbol?
        let showsLabsLabel: Bool

        init(
            id: String,
            title: String,
            subtitle: String? = nil,
            icon: SFSymbol? = nil,
            showsLabsLabel: Bool = false
        ) {
            self.id = id
            self.title = title
            self.subtitle = Self.deduplicated(subtitle: subtitle, title: title)
            self.icon = icon
            self.showsLabsLabel = showsLabsLabel
        }

        private static func deduplicated(subtitle: String?, title: String) -> String? {
            guard let subtitle else { return nil }
            let normalizedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedSubtitle.localizedCaseInsensitiveCompare(normalizedTitle) != .orderedSame else {
                return nil
            }
            return subtitle
        }

        func matches(searchTerm: String) -> Bool {
            if title.localizedStandardContains(searchTerm) {
                return true
            }
            return subtitle?.localizedStandardContains(searchTerm) ?? false
        }
    }

    func filtered(searchTerm: String) -> ListPickerContent {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return self }
        let matchingSections: [Section] = sections.compactMap { section in
            if section.title.localizedStandardContains(term) {
                return section
            }
            let items = section.items.filter { $0.matches(searchTerm: term) }
            guard !items.isEmpty else { return nil }
            return Section(id: section.id, title: section.title, items: items)
        }
        return ListPickerContent(sections: matchingSections)
    }
}

struct ListPicker: View {
    let title: String
    @Binding var selection: ListPickerContent.Item
    let content: ListPickerContent

    var body: some View {
        NavigationLink {
            ListPickerContentView(title: title, selection: $selection, content: content)
        } label: {
            HStack {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(selection.title)
                    .frame(alignment: .trailing)
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                    .truncationMode(.middle)
                    .lineLimit(1)
            }
        }
    }
}

struct ListPickerContentView: View {
    let title: String
    @Binding var selection: ListPickerContent.Item
    let content: ListPickerContent

    @State private var searchTerm: String

    init(
        title: String,
        selection: Binding<ListPickerContent.Item>,
        content: ListPickerContent,
        searchTerm: String = ""
    ) {
        self.title = title
        self._selection = selection
        self.content = content
        self._searchTerm = State(initialValue: searchTerm)
    }

    var body: some View {
        List {
            if !trimmedSearchTerm.isEmpty, filteredContent.sections.isEmpty {
                noSearchResultsSection
            }
            ForEach(filteredContent.sections, id: \.id) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.id) { item in
                        Button {
                            selection = item
                        } label: {
                            Label {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.title)
                                        if let subtitle = item.subtitle {
                                            Text(subtitle)
                                                .font(.footnote)
                                                .foregroundColor(Color(uiColor: .secondaryLabel))
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    if item.showsLabsLabel {
                                        LabsLabel()
                                    }
                                    if selection.id == item.id {
                                        Image(systemSymbol: .checkmark)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            } icon: {
                                if let icon = item.icon {
                                    Image(systemSymbol: icon)
                                        .frame(width: DesignSystem.Spaces.three, alignment: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchTerm)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
    }

    private var trimmedSearchTerm: String {
        searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredContent: ListPickerContent {
        content.filtered(searchTerm: searchTerm)
    }

    private var noSearchResultsSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.two) {
                Image(systemSymbol: .magnifyingglass)
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(L10n.Settings.Search.NoResults.title(trimmedSearchTerm))
                    .font(.headline)
                Text(L10n.Settings.Search.NoResults.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, DesignSystem.Spaces.two)
        }
        .listRowBackground(Color.clear)
    }
}

#Preview("List picker") {
    ListPickerPreview.standard
}

#Preview("List picker content") {
    ListPickerPreview.content
}

#Preview("List picker searching") {
    ListPickerPreview.searching
}

#Preview("List picker no results") {
    ListPickerPreview.noResults
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

    static var searching: some View {
        NavigationView {
            ListPickerContentView(
                title: "Title 1",
                selection: .constant(.init(id: "2", title: "aaaa")),
                content: sampleContent,
                searchTerm: "bbbb"
            )
        }
    }

    static var noResults: some View {
        NavigationView {
            ListPickerContentView(
                title: "Title 1",
                selection: .constant(.init(id: "2", title: "aaaa")),
                content: sampleContent,
                searchTerm: "zzzz"
            )
        }
    }

    static var content: some View {
        NavigationView {
            ListPickerContentView(
                title: "Title 1",
                selection: .constant(.init(id: "2", title: "aaaa")),
                content: sampleContent
            )
        }
    }

    private static var sampleContent: ListPickerContent {
        .init(sections: [
            .init(id: "1", title: "Section 1", items: [
                .init(id: "1", title: "Abc", subtitle: "A longer explanation", icon: .house),
                .init(id: "2", title: "aaaa", icon: .star),
                .init(id: "3", title: "bbbb", subtitle: "bbbb", icon: .bell),
                .init(id: "4", title: "ccccc", icon: .gearshape),
            ]),
            .init(id: "2", title: "Section 2", items: [
                .init(id: "5", title: "Abc", icon: .safari),
                .init(id: "6", title: "aaaa", icon: .command),
                .init(id: "7", title: "bbbb", icon: .ladybug),
                .init(id: "8", title: "ccccc", icon: .nosign),
            ]),
        ])
    }
}
