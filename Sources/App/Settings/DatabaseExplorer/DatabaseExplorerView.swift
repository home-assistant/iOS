import GRDB
import SFSafeSymbols
import Shared
import SwiftUI

struct DatabaseExplorerView: View {
    @State private var tables: [String] = []

    var body: some View {
        List {
            ForEach(tables, id: \.self) { table in
                NavigationLink {
                    DatabaseTableDetailView(tableName: table)
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: .tablecells)
                            .foregroundStyle(Color.haPrimary)
                        Text(table)
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.DatabaseExplorer.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadTables()
        }
    }

    private func loadTables() {
        do {
            tables = try Current.database().read { db in
                try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
            }
        } catch {
            Current.Log.error("Failed to load database tables: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        DatabaseExplorerView()
    }
}
