import CoreGraphics

/// Shared metrics for the rows on the migration screens, so the disclosure rows on the intro and the
/// step rows on the progress screen sit on the same rhythm.
enum AppMigrationRowMetrics {
    /// Every row reserves at least this much height, so a one-line row and a wrapping one do not make
    /// the group look unevenly spaced.
    static let minimumHeight: CGFloat = 50

    /// Rounder than `HACornerRadius.standard`, which is shared with the rest of the app and not worth
    /// changing for one flow.
    static let cornerRadius: CGFloat = 16

    /// How far a row's separator is inset so it starts under the text rather than under the symbol.
    /// One per row type, because their symbols are different sizes.
    static let disclosureSeparatorInset: CGFloat = 24
    static let stepSeparatorInset: CGFloat = 36
}
