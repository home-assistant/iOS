import Foundation
import Shared

/// Which migration screen is on display, if any.
enum AppMigrationPresentation: Identifiable, Equatable {
    /// This app is the one being replaced, offering to hand its data over.
    case export
    /// This app is the one taking over, applying a slice of a handoff it just received.
    case importing(chunk: AppMigrationChunk)

    /// Deliberately stable across the slices of one handoff: identifying by session rather than by
    /// chunk keeps SwiftUI from tearing down and rebuilding the import screen — and its view model —
    /// on every round trip.
    var id: String {
        switch self {
        case .export: return "export"
        case let .importing(chunk): return "import-\(chunk.sessionID)"
        }
    }
}
