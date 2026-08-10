import Foundation

/// Converts the app's GRDB database to and from portable `CloudSyncSnapshot` payloads
/// for iCloud sync.
public protocol CloudSyncSnapshotSerializerProtocol {
    /// Reads every GRDB table into a snapshot.
    func exportSnapshot() throws -> CloudSyncSnapshot

    /// Replaces the contents of every locally-known table present in the snapshot, in a
    /// single transaction. Tables or columns the snapshot carries that this build does
    /// not know are ignored, so devices on different app versions can still sync.
    func importSnapshot(_ snapshot: CloudSyncSnapshot) throws
}
