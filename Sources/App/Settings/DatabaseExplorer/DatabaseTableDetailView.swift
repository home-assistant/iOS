import GRDB
import SFSafeSymbols
import Shared
import SwiftUI

private extension Dictionary where Key == String, Value == String {
    func sortedKeys() -> [String] {
        let priorityKeys = ["id", "entityId", "serverId", "name", "areaId", "uniqueId"]
        let keys = Array(self.keys)
        
        // Separate priority keys that exist in the dictionary from other keys
        let existingPriorityKeys = priorityKeys.filter { keys.contains($0) }
        let remainingKeys = keys.filter { !priorityKeys.contains($0) }.sorted()
        
        return existingPriorityKeys + remainingKeys
    }
}

struct DatabaseTableDetailView: View {
    let tableName: String

    @StateObject private var viewModel: DatabaseTableDetailViewModel

    init(tableName: String) {
        self.tableName = tableName
        _viewModel = StateObject(wrappedValue: DatabaseTableDetailViewModel(tableName: tableName))
    }

    var body: some View {
        List {
            serverFilter
            ForEach(viewModel.filteredRows.indices, id: \.self) { index in
                rowView(viewModel.filteredRows[index])
            }
            if viewModel.filteredRows.isEmpty {
                Text(L10n.Settings.DatabaseExplorer.noEntries)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .searchable(text: $viewModel.searchText)
        .navigationTitle(tableName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadData()
        }
    }

    @ViewBuilder
    private var serverFilter: some View {
        if viewModel.hasServerIdColumn, Current.servers.all.count > 1 {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button {
                            viewModel.selectedServerId = nil
                        } label: {
                            PillView(
                                text: L10n.ClientEvents.EventType.all,
                                selected: viewModel.selectedServerId == nil
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(Current.servers.all, id: \.identifier) { server in
                            Button {
                                viewModel.selectedServerId = server.identifier.rawValue
                            } label: {
                                PillView(
                                    text: server.info.name,
                                    selected: viewModel.selectedServerId == server.identifier.rawValue
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.listSectionSpacing(DesignSystem.Spaces.one)
                } else {
                    view
                }
            }
        }
    }

    private func rowView(_ row: [String: String]) -> some View {
        NavigationLink {
            DatabaseRowDetailView(row: row)
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                ForEach(row.sortedKeys().prefix(3), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(row[key] ?? "nil")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                if row.count > 3 {
                    Text(L10n.Settings.DatabaseExplorer.moreFields(row.count - 3))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

final class DatabaseTableDetailViewModel: ObservableObject {
    let tableName: String

    @Published var rows: [[String: String]] = []
    @Published var searchText: String = ""
    @Published var selectedServerId: String?
    @Published var hasServerIdColumn: Bool = false

    init(tableName: String) {
        self.tableName = tableName
    }

    var filteredRows: [[String: String]] {
        var result = rows

        // Filter by serverId if selected and column exists
        if let serverId = selectedServerId, hasServerIdColumn {
            result = result.filter { row in
                row["serverId"] == serverId
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { row in
                row.values.contains { value in
                    value.lowercased().contains(searchText.lowercased())
                }
            }
        }

        return result
    }

    func loadData() {
        do {
            let database = Current.database()

            // Validate table name exists in the database to prevent SQL injection
            let tableExists = try database.read { db in
                try String.fetchOne(
                    db,
                    sql: "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
                    arguments: [tableName]
                ) != nil
            }

            guard tableExists else {
                Current.Log.error("Table '\(tableName)' not found in database")
                return
            }

            // Check if table has serverId column
            let columns = try database.read { db in
                try db.columns(in: tableName).map(\.name)
            }
            hasServerIdColumn = columns.contains("serverId")

            // Fetch rows with a limit to prevent memory issues on large tables
            // Table name is already validated to exist above via parameterized query
            rows = try database.read { db in
                let quotedTableName = "\"\(tableName.replacingOccurrences(of: "\"", with: "\"\""))\""
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM \(quotedTableName) LIMIT 1000")
                var result: [[String: String]] = []
                while let row = try cursor.next() {
                    var dict: [String: String] = [:]
                    for column in row.columnNames {
                        if let value = row[column] {
                            dict[column] = String(describing: value)
                        } else {
                            dict[column] = "nil"
                        }
                    }
                    result.append(dict)
                }
                return result
            }
        } catch {
            Current.Log.error("Failed to load table data: \(error)")
        }
    }
}

struct DatabaseRowDetailView: View {
    let row: [String: String]

    var body: some View {
        List {
            ForEach(row.sortedKeys(), id: \.self) { key in
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(row[key] ?? "nil")
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(L10n.Settings.DatabaseExplorer.rowDetail)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        DatabaseTableDetailView(tableName: "hAAppEntity")
    }
}
