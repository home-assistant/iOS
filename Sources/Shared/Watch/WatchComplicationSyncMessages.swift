import Foundation

/// Constants for complication sync message identifiers and content keys
/// Used for paginated complication sync between iPhone and Apple Watch
public enum WatchComplicationSyncMessages {
    /// Message identifiers for complication sync protocol
    public enum Identifier {
        /// Request to sync a single complication by index (sent by watch)
        public static let syncComplication = "syncComplication"

        /// Response containing complication data (sent by phone)
        public static let syncComplicationResponse = "syncComplicationResponse"

        /// Legacy message to sync all complications at once (deprecated)
        public static let syncComplications = "syncComplications"
    }

    /// Content keys used in complication sync messages
    public enum ContentKey {
        /// The index of the complication to request/send (Int)
        public static let index = "index"

        /// The serialized complication data (Data)
        public static let complicationData = "complicationData"

        /// Whether more complications are pending after this one (Bool)
        public static let hasMore = "hasMore"

        /// The total number of complications being synced (Int)
        public static let total = "total"

        /// Error message if sync failed (String)
        public static let error = "error"

        /// Success flag for legacy sync (Bool)
        public static let success = "success"

        /// Count of complications for legacy sync (Int)
        public static let count = "count"
    }
}
