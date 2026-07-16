import CryptoKit
import Foundation
import GRDB

/// A snapshot of the phone-owned data the watch can't obtain anywhere else: complications
/// (edited on the phone) and the servers/credentials state.
///
/// Server reference data (entities, areas, Assist pipelines, registries) is NOT carried here
/// anymore — the watch fetches it directly from Home Assistant over its own websocket connection
/// (`WatchDirectDatabaseSync`), no paired iPhone required. What remains on this mirror is the
/// data only the phone can author. The snapshot is streamed as chunked guaranteed messages when
/// pulled, and pushed proactively over `transferFile` when complications or servers change.
public struct WatchDatabaseMirror: WatchCodable {
    /// Blob identifier used when the phone proactively *pushes* the mirror to the watch over
    /// `transferFile` (background-capable), in addition to the watch-initiated chunked pull.
    public static let blobIdentifier = "watchDatabaseMirror.push"
    /// Key under which sync requests, sync-start replies and push metadata carry the per-table
    /// digest map used for delta syncs (see `tableDigests()`).
    public static let digestsKey = "digests"

    /// Legacy complications + modern configs so the watch reload routine is another chance to receive
    /// them (in addition to the background WatchConnectivity context push).
    ///
    /// Optional on purpose: `nil` means "this sync did not carry complication data" — an older build, a
    /// partial payload, or a decode/read failure — and the watch must RETAIN whatever it already has. A
    /// non-nil value (even an empty array) is authoritative and replaces the local rows, which is how a
    /// genuine "user deleted them all" propagates. This is what stops a half/broken sync from wiping the
    /// existing complications off the watch.
    public var complications: [WatchComplication]?
    public var complicationConfigs: [WatchComplicationConfig]?
    /// The phone's servers (`ServerManager.restorableState()` encoding), so every sync — the chunked
    /// pull and the proactive background push — also refreshes the watch's servers *in addition to*
    /// the on-demand `serversConfigSync` interactive exchange (which additionally carries the mTLS
    /// client-certificate bundles; those Keychain materials stay off the mirror on purpose).
    /// Same contract as the complication fields: `nil` means "not carried", retain what's local.
    public var servers: Data?

    public init(
        complications: [WatchComplication]? = nil,
        complicationConfigs: [WatchComplicationConfig]? = nil,
        servers: Data? = nil
    ) {
        self.complications = complications
        self.complicationConfigs = complicationConfigs
        self.servers = servers
    }

    private enum CodingKeys: String, CodingKey {
        case complications, complicationConfigs, servers
    }

    // Decode defensively: a payload from a different build (or any format drift) must not fail the
    // whole mirror. A missing key OR a decode failure yields `nil` (retain existing rows); only a
    // value that actually decodes is treated as authoritative. Reference-table keys that older
    // phones still encode (entities/areas/pipelines) are simply ignored.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.complications = (try? container.decodeIfPresent([WatchComplication].self, forKey: .complications))
            .flatMap { $0 }
        self.complicationConfigs = (try? container.decodeIfPresent(
            [WatchComplicationConfig].self,
            forKey: .complicationConfigs
        )).flatMap { $0 }
        self.servers = (try? container.decodeIfPresent(Data.self, forKey: .servers)).flatMap { $0 }
    }

    /// Read the current phone-owned data (called on the phone).
    public static func snapshot() throws -> WatchDatabaseMirror {
        // A read failure sends `nil` (not `[]`) so the watch retains its rows rather than being told the
        // phone has none — only a successful read is authoritative.
        let complications = try? WatchComplication.all()
        let configs = try? WatchComplicationConfig.all()
        // Resolved outside the GRDB read: servers live in their own store, not the database.
        let servers = Current.servers.restorableState()

        return WatchDatabaseMirror(
            complications: complications,
            complicationConfigs: configs,
            servers: servers
        )
    }

    /// Overwrite the local complication tables with this snapshot (called on the watch). The
    /// servers blob is applied separately by `WatchServerSync.applyMirroredServers`.
    public func apply() throws {
        try Current.database().write { db in
            // Only replace the complication tables when this sync actually carried them. A `nil` here is
            // a half/broken/older sync — keep the watch's existing complications instead of wiping them.
            if let complications {
                try WatchComplication.deleteAll(db)
                for complication in complications {
                    try complication.insert(db)
                }
            }
            if let complicationConfigs {
                try WatchComplicationConfig.deleteAll(db)
                for config in complicationConfigs {
                    try config.insert(db)
                }
            }
        }
    }

    // MARK: - Delta sync digests

    /// Opaque per-table digests of this snapshot, generated and compared ONLY on the phone
    /// (property-list encoding isn't guaranteed byte-stable across devices, so the watch never
    /// computes these — it stores the map verbatim and echoes it on the next sync request).
    /// A group that is `nil` produces no digest, can never "match", and is always carried.
    public func tableDigests() -> [String: String] {
        let encoder = PropertyListEncoder()
        var digests: [String: String] = [:]
        // The complication tables travel and change together; one digest covers both.
        if let complications, let complicationConfigs,
           let complicationsData = try? encoder.encode(complications),
           let configsData = try? encoder.encode(complicationConfigs) {
            digests["complications"] = Self.digest(of: [complicationsData, configsData])
        }
        if let servers {
            digests["servers"] = Self.digest(of: [servers])
        }
        return digests
    }

    private static func digest(of datas: [Data]) -> String {
        var hasher = SHA256()
        for data in datas {
            hasher.update(data: data)
        }
        return Data(hasher.finalize()).base64EncodedString()
    }

    /// A copy with every table whose digest positively matches the watch's stored digests omitted
    /// (`nil` = retain on the watch). Groups without a digest on either side are always carried.
    public func omittingTables(
        matching storedDigests: [String: String],
        currentDigests: [String: String]
    ) -> WatchDatabaseMirror {
        func matches(_ key: String) -> Bool {
            guard let current = currentDigests[key], let stored = storedDigests[key] else { return false }
            return current == stored
        }
        var copy = self
        if matches("complications") {
            copy.complications = nil
            copy.complicationConfigs = nil
        }
        if matches("servers") { copy.servers = nil }
        return copy
    }
}
