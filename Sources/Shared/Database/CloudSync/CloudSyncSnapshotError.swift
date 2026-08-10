import Foundation

/// Errors thrown while exporting or importing an iCloud sync snapshot.
public enum CloudSyncSnapshotError: LocalizedError {
    /// The snapshot was written by a newer app version in a format this build cannot read.
    case incompatibleFormatVersion(Int)

    public var errorDescription: String? {
        switch self {
        case let .incompatibleFormatVersion(version):
            return L10n.SettingsDetails.CloudSync.Error.incompatibleSnapshot(version)
        }
    }
}
