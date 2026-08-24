import Foundation

/// Thrown by the first import step when the handoff is only partly here.
///
/// Not an error the user ever sees: it unwinds the import so the flow can ask the other app for the
/// next slice and pick up where it left off when that arrives.
enum AppMigrationImportPause: Error {
    case awaitingMoreChunks
}
