import Foundation

/// One slice of a payload in transit between the two apps.
///
/// A URL has no documented length limit and the platform will silently truncate one that is too
/// long, so a payload that does not comfortably fit in a single link is split and handed over a
/// slice at a time, each in its own round trip. Most migrations are one chunk and never bounce.
public struct AppMigrationChunk: Equatable {
    /// Identifies one migration attempt, so a half-delivered payload from an abandoned attempt is
    /// never mixed with a later one.
    public let sessionID: String
    public let index: Int
    public let total: Int
    /// The base64url slice. Concatenating every chunk's `data` in index order rebuilds the payload.
    public let data: String

    public var isLast: Bool { index == total - 1 }

    public init(sessionID: String, index: Int, total: Int, data: String) {
        self.sessionID = sessionID
        self.index = index
        self.total = total
        self.data = data
    }

    /// Wire format: `1.<session>.<index>.<total>.<data>`. Dot-separated because base64url never
    /// contains a dot, so the header can be split off without escaping or a nested encoder.
    private static let version = "1"

    public var encoded: String {
        [Self.version, sessionID, String(index), String(total), data].joined(separator: ".")
    }

    public init?(encoded: String) {
        // Split only the header off: the payload may not contain dots, but splitting the whole
        // string would still be wasteful for a large chunk.
        let parts = encoded.split(separator: ".", maxSplits: 4, omittingEmptySubsequences: false)
        guard parts.count == 5,
              parts[0] == Self.version,
              let index = Int(parts[2]),
              let total = Int(parts[3]),
              index >= 0, total > 0, index < total,
              !parts[1].isEmpty, !parts[4].isEmpty else {
            return nil
        }
        self.init(sessionID: String(parts[1]), index: index, total: total, data: String(parts[4]))
    }
}
