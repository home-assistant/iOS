import SFSafeSymbols
import Shared
import SwiftUI

/// Log of past sync runs: when each one happened, for which list pairing, and every change it
/// applied. Only runs that changed something (or failed) are recorded.
struct RemindersSyncHistoryView: View {
    @State private var entries: [RemindersSyncHistoryEntry] = []
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            if entries.isEmpty {
                Text(L10n.RemindersSync.History.empty)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: entry.success ? .checkmarkCircleFill : .exclamationmarkTriangleFill)
                            .foregroundStyle(entry.success ? .green : .orange)
                        Text(entry.listLabel)
                            .font(.subheadline.bold())
                    }
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let error = entry.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    ForEach(Array(entry.detailLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(L10n.RemindersSync.History.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.RemindersSync.History.clear) {
                    showClearConfirmation = true
                }
                .disabled(entries.isEmpty)
                .confirmationDialog(
                    L10n.RemindersSync.History.ClearConfirm.title,
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.RemindersSync.History.ClearConfirm.button, role: .destructive) {
                        RemindersSyncHistoryEntry.deleteAll()
                        entries = []
                    }
                    Button(L10n.cancelLabel, role: .cancel) {}
                }
            }
        }
        .onAppear {
            entries = RemindersSyncHistoryEntry.all()
        }
    }
}

#Preview {
    NavigationView {
        RemindersSyncHistoryView()
    }
}
