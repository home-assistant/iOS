import Foundation

/// Constants for complication sync message identifiers and content keys
/// Used for paginated complication sync between iPhone and Apple Watch
enum WatchComplicationSyncMessages {
    /// Message identifiers for complication sync protocol
    enum Identifier {
        /// Request to sync a single complication by index (sent by watch)
        static let syncComplication = "syncComplication"

        /// Response containing complication data (sent by phone)
        static let syncComplicationResponse = "syncComplicationResponse"

        /// Legacy message to sync all complications at once (deprecated)
        static let syncComplications = "syncComplications"
    }

    /// Content keys used in complication sync messages
    enum ContentKey {
        /// The index of the complication to request/send (Int)
        static let index = "index"

        /// The serialized complication data (Data)
        static let complicationData = "complicationData"

        /// Whether more complications are pending after this one (Bool)
        static let hasMore = "hasMore"

        /// The total number of complications being synced (Int)
        static let total = "total"

        /// Error message if sync failed (String)
        static let error = "error"

        /// Success flag for legacy sync (Bool)
        static let success = "success"

        /// Count of complications for legacy sync (Int)
        static let count = "count"
    }
}
