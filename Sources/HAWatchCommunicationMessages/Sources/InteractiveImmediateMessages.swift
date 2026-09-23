import Foundation

/// Identifiers for interactive (request/reply) messages sent over WatchConnectivity's `sendMessage`.
/// Raw values cross the wire — never repurpose them.
public enum InteractiveImmediateMessages: String, CaseIterable {
    case ping
    case magicItemPressed
    case pushAction = "PushAction"
    case assistPipelinesFetch
    case assistAudioDataChunked
    /// Watch → phone: run an Assist pipeline with a written prompt instead of a recording,
    /// `{text, pipelineId, serverId}`. The phone runs the pipeline and streams the result back
    /// through the same `assistIntentEndResponse`/`assistTTSResponse`/`assistError` messages the
    /// audio flow uses.
    case assistTextInput
    case watchConfig
    /// Watch → phone: ask the phone for the list of items the user can add to the watch
    /// configuration (scripts/scenes/automations across all servers). The phone owns the entity
    /// database, so it builds the list and replies with `watchConfigAvailableItemsResponse`.
    ///
    /// - Note: Deprecated wire flow. The watch has built this list locally from the mirrored
    ///   database since the database sync shipped and no longer sends this message. The phone
    ///   handler stays for one release cycle so pre-mirror watch builds keep working; after that,
    ///   remove this case, `watchConfigAvailableItemsResponse` and the phone handler together.
    case watchConfigAvailableItems
    /// Watch → phone: persist an edited `WatchConfig` (add/reorder/delete/customize done on the
    /// watch). The phone writes it to GRDB and replies with the same payload as `watchConfig`
    /// (`watchConfigResponse`) so the watch refreshes its cache with server-resolved info.
    case watchConfigUpdate
    /// Watch → phone: begin a full database sync. The phone snapshots the reference GRDB tables
    /// (addable entities, areas, Assist pipelines), encodes them, splits the payload into ordered
    /// chunks, and replies with `watchDatabaseMirrorResponse` carrying `{transferId, totalChunks,
    /// totalBytes}`. The watch then pulls each chunk in order (see `watchDatabaseMirrorChunk`).
    case watchDatabaseMirror
    /// Watch → phone: request one chunk of an in-progress database sync, `{transferId, index}`. The
    /// phone replies with `watchDatabaseMirrorChunkResponse` `{index, chunkData}`. Each request doubles
    /// as the acknowledgement of the previous chunk, keeping the transfer ordered and reliable.
    case watchDatabaseMirrorChunk
    /// Watch → phone: ask the phone for the latest server configuration. The phone replies with the
    /// encoded servers and any mTLS client certificate bundles inline (see WatchCommunicatorService).
    case serversConfigSync
    /// Watch → phone: ask the phone to present the client-certificate (mTLS) import screen so the
    /// user can supply a `.p12` + password for the given server. The phone can't foreground itself,
    /// so the screen appears the next time the user opens the iPhone app.
    case clientCertImportRequest
    /// Watch → phone: ask which Home Assistant areas a vacuum can be told to clean, `{entityId,
    /// serverId}`. The mapping lives in the entity registry, which Home Assistant only serves over
    /// WebSocket — a transport the watch doesn't have — so the phone fetches it and replies with
    /// `vacuumCleanableAreasResponse`. Only sent while the phone is immediately reachable; the
    /// watch hides the option otherwise.
    case vacuumCleanableAreas
    /// Watch → phone: perform one HTTP request on the watch's behalf, `WatchHTTPRequestPayload`.
    /// The phone re-bases the URL against its own active URL for that server and dials it with the
    /// same certificate-aware session the watch would have used, replying with
    /// `httpRequestResponse`.
    ///
    /// This carries transport only — the watch still builds the request, owns its credentials and
    /// parses the answer. What it borrows is the phone's position on the network: when the watch
    /// routes through the phone, Apple's proxying hides the Wi-Fi it is really on, so the watch
    /// can't tell that the internal URL would work and falls back to a remote one that may not be
    /// reachable from inside the LAN at all (a router without NAT loopback). Letting the phone
    /// dial makes the URL choice and the network vantage point the same device.
    case httpRequest
}
