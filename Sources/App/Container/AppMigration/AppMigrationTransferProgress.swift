import Foundation

/// How far a multi-link handoff has got, for the bar on the progress screen.
///
/// Only produced when a payload genuinely needs more than one link. The common case is a single
/// chunk that crosses without a round trip, and the progress screen shows no bar at all — there is
/// nothing to report and a bar that instantly fills reads as noise.
struct AppMigrationTransferProgress: Equatable {
    /// How many slices have made it across.
    let completed: Int
    let total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}
