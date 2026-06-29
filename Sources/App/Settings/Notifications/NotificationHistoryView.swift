import SFSafeSymbols
import Shared
import SwiftUI

struct NotificationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NotificationHistoryViewModel()
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            kindFilter
            entriesList
        }
        .searchable(text: $viewModel.searchTerm)
        .refreshable {
            viewModel.loadEntries()
        }
        .navigationTitle(L10n.SettingsDetails.Notifications.History.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showClearConfirmation = true
                } label: {
                    Text(verbatim: L10n.SettingsDetails.Notifications.History.clear)
                }
                .disabled(viewModel.entries.isEmpty)
                .confirmationDialog(
                    L10n.SettingsDetails.Notifications.History.ClearConfirm.title,
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.cancelLabel, role: .cancel) {
                        /* no-op */
                    }
                    Button(L10n.yesLabel, role: .destructive) {
                        Current.notificationHistoryStore.clearAllEntries()
                        viewModel.loadEntries()
                    }
                } message: {
                    Text(verbatim: L10n.SettingsDetails.Notifications.History.ClearConfirm.message)
                }
            }
        }
        .onAppear {
            viewModel.loadEntries()
        }
    }

    @ViewBuilder
    private var entriesList: some View {
        ForEach(filteredEntries, id: \.id) { entry in
            listItem(entry)
        }
        if filteredEntries.isEmpty {
            Text(verbatim: L10n.SettingsDetails.Notifications.History.empty)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var filteredEntries: [NotificationHistoryEntry] {
        viewModel.entries.filter { entry in
            if let kindFilter = viewModel.kindFilter, entry.kind != kindFilter {
                return false
            }
            guard !viewModel.searchTerm.isEmpty else {
                return true
            }
            let term = viewModel.searchTerm.lowercased()
            return [entry.title, entry.subtitle, entry.body, entry.payloadJSON]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(term) }
        }
    }

    private var kindFilter: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Group {
                        Button {
                            viewModel.kindFilter = nil
                        } label: {
                            PillView(
                                text: L10n.SettingsDetails.Notifications.History.Kind.all,
                                selected: viewModel.kindFilter == nil
                            )
                        }
                        ForEach(NotificationHistoryEntry.Kind.allCases.sorted { lhs, rhs in
                            lhs.displayText < rhs.displayText
                        }, id: \.self) { kind in
                            Button {
                                viewModel.kindFilter = kind
                            } label: {
                                PillView(
                                    text: kind.displayText,
                                    selected: viewModel.kindFilter == kind
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeIn(duration: 0.2), value: viewModel.kindFilter)
                }
            }
            .listRowBackground(Color.clear)
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.scrollClipDisabled(true)
                } else {
                    view
                }
            }
        } footer: {
            Text(L10n.SettingsDetails.Notifications.History.footer)
        }
        .modify { view in
            if #available(iOS 17.0, *) {
                view.listSectionSpacing(DesignSystem.Spaces.one)
            } else {
                view
            }
        }
    }

    private func listItem(_ entry: NotificationHistoryEntry) -> some View {
        NavigationLink {
            entryDescription(entry)
        } label: {
            VStack(spacing: DesignSystem.Spaces.one) {
                HStack {
                    Group {
                        dateTimeLabel(entry.date)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.kind.displayText)
                            .frame(alignment: .trailing)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                Text(entry.displayTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let body = entry.body, !body.isEmpty, body != entry.displayTitle {
                    Text(body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func dateTimeLabel(_ date: Date) -> Text {
        Text(date, style: .date)
            +
            Text(verbatim: " ")
            +
            Text(date, style: .time)
    }

    private func entryDescription(_ entry: NotificationHistoryEntry) -> some View {
        NotificationHistoryDetailView(entry: entry)
    }
}

struct NotificationHistoryDetailView: View {
    let entry: NotificationHistoryEntry

    @State private var didCopy = false

    private var payloadRows: [PayloadRow] {
        guard let payloadJSON = entry.payloadJSON, let node = JSONNode(jsonString: payloadJSON) else {
            return []
        }
        return node.flattened(key: nil, depth: 0, path: "root")
    }

    var body: some View {
        List {
            payloadSection
            copySection
        }
        .navigationTitle(
            Text(entry.date, style: .date)
                + Text(verbatim: " ")
                + Text(entry.date, style: .time)
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var payloadSection: some View {
        Section {
            let rows = payloadRows
            if rows.isEmpty {
                Text(verbatim: L10n.SettingsDetails.Notifications.History.Detail.empty)
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows) { row in
                    payloadRow(row)
                }
            }
        } header: {
            Text(L10n.SettingsDetails.Notifications.History.Detail.payload)
        }
    }

    private func payloadRow(_ row: PayloadRow) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            if let key = row.key {
                Text(key)
                    .font(.subheadline)
                    .fontWeight(row.isContainer ? .bold : .semibold)
                    .foregroundColor(.primary)
            }
            if let value = row.value {
                Text(value)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, CGFloat(row.depth) * DesignSystem.Spaces.two)
    }

    private var copySection: some View {
        Section {
            Button {
                copyPayload()
            } label: {
                Label {
                    Text(
                        verbatim: didCopy
                            ? L10n.SettingsDetails.Notifications.History.Detail.copied
                            : L10n.SettingsDetails.Notifications.History.Detail.copy
                    )
                } icon: {
                    Image(systemSymbol: didCopy ? .checkmark : .docOnDoc)
                }
                .foregroundColor(.accentColor)
            }
            .disabled(entry.payloadJSON == nil)
        }
    }

    private func copyPayload() {
        guard let payloadJSON = entry.payloadJSON else { return }
        UIPasteboard.general.string = payloadJSON
        withAnimation { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { didCopy = false }
        }
    }
}

private struct PayloadRow: Identifiable {
    let id: String
    let depth: Int
    let key: String?
    let value: String?
    let isContainer: Bool
}

private indirect enum JSONNode {
    case object([(key: String, value: JSONNode)])
    case array([JSONNode])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        self = JSONNode(value: object)
    }

    init(value: Any) {
        if let dictionary = value as? [String: Any] {
            self = .object(
                dictionary
                    .sorted { $0.key < $1.key }
                    .map { (key: $0.key, value: JSONNode(value: $0.value)) }
            )
        } else if let array = value as? [Any] {
            self = .array(array.map { JSONNode(value: $0) })
        } else if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.stringValue)
            }
        } else if let string = value as? String {
            self = .string(string)
        } else if value is NSNull {
            self = .null
        } else {
            self = .string(String(describing: value))
        }
    }

    private var scalarValue: String? {
        switch self {
        case let .string(string): return string
        case let .number(number): return number
        case let .bool(bool): return bool ? "true" : "false"
        case .null: return "null"
        case .object, .array: return nil
        }
    }

    func flattened(key: String?, depth: Int, path: String) -> [PayloadRow] {
        switch self {
        case let .object(pairs):
            var rows: [PayloadRow] = []
            var childDepth = depth
            if let key {
                rows.append(PayloadRow(id: path, depth: depth, key: key, value: nil, isContainer: true))
                childDepth += 1
            }
            for pair in pairs {
                rows += pair.value.flattened(key: pair.key, depth: childDepth, path: "\(path).\(pair.key)")
            }
            return rows
        case let .array(items):
            var rows: [PayloadRow] = []
            var childDepth = depth
            if let key {
                rows.append(PayloadRow(id: path, depth: depth, key: key, value: nil, isContainer: true))
                childDepth += 1
            }
            for (index, item) in items.enumerated() {
                rows += item.flattened(key: "[\(index)]", depth: childDepth, path: "\(path).\(index)")
            }
            return rows
        default:
            return [PayloadRow(id: path, depth: depth, key: key, value: scalarValue, isContainer: false)]
        }
    }
}

@MainActor
final class NotificationHistoryViewModel: ObservableObject {
    @Published var entries: [NotificationHistoryEntry] = []
    @Published var searchTerm: String = ""
    @Published var kindFilter: NotificationHistoryEntry.Kind?

    func loadEntries() {
        entries = Current.notificationHistoryStore.getEntries().sorted(by: { $0.date > $1.date })
    }
}

#Preview {
    NavigationView {
        NotificationHistoryView()
    }
}
