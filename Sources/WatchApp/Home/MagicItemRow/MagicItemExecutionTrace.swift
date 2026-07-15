import Foundation
import Shared

/// Collects a step-by-step log of a single magic item execution for the developer "Verbose item
/// execution" screen. Entries are appended from the execution flow and rendered live by
/// `MagicItemExecutionTraceView`. Messages are developer-facing diagnostics and stay English-only,
/// like client events.
final class MagicItemExecutionTrace: ObservableObject {
    enum Level {
        case info
        case success
        case error
    }

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let level: Level
        let message: String
    }

    @Published private(set) var entries: [Entry] = []
    /// True once the execution reported a terminal result. Entries may still arrive after this (e.g.
    /// a late reply following the UI timeout) and are appended normally.
    @Published private(set) var isFinished = false

    private let startDate = Current.date()

    /// Seconds since the trace started, shown alongside each entry.
    func elapsed(for entry: Entry) -> String {
        String(format: "+%.2fs", entry.date.timeIntervalSince(startDate))
    }

    func log(_ level: Level, _ message: String) {
        Current.Log.info("[ItemExecutionTrace] \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.entries.append(.init(date: Current.date(), level: level, message: message))
        }
    }

    func finish() {
        DispatchQueue.main.async { [weak self] in
            self?.isFinished = true
        }
    }
}
