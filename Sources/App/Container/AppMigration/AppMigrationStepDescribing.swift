import Foundation
import SFSafeSymbols

/// A step either side of the migration can show in its progress list. Both step enums conform, so
/// one progress screen renders both directions.
protocol AppMigrationStepDescribing: Identifiable, CaseIterable, Hashable {
    var title: String { get }
    var icon: SFSymbol { get }
}
