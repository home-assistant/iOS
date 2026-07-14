import Foundation

/// Identifiers for the replies to `InteractiveImmediateMessages`, and for phone → watch one-way
/// messages emitted during an Assist session. Raw values cross the wire — never repurpose them.
public enum InteractiveImmediateResponses: String, CaseIterable {
    case pong
    case magicItemRowPressedResponse
    case pushActionResponse = "PushActionResponse"
    case assistPipelinesFetchResponse
    case assistAudioDataResponse
    /// Phone → watch: per-chunk acknowledgement of `assistAudioDataChunked`, carrying
    /// `{acknowledged, chunkIndex, totalChunks}`. The watch sends the next chunk only after
    /// receiving this, so audio streams with backpressure instead of flooding the session.
    case assistAudioChunkAck
    case assistSTTResponse
    case assistIntentEndResponse
    case assistTTSResponse
    case assistError
    case watchConfigResponse
    case emptyWatchConfigResponse
    /// Phone → watch: reply to `watchConfigAvailableItems`, carrying the encoded
    /// `WatchConfigAvailableItems` (the items the user can add, grouped by server).
    ///
    /// - Note: Deprecated wire flow — see `InteractiveImmediateMessages.watchConfigAvailableItems`.
    case watchConfigAvailableItemsResponse
    /// Phone → watch: reply to the `watchDatabaseMirror` start request, carrying `{transferId,
    /// totalChunks, totalBytes}` so the watch can pull the chunks in order and show progress.
    case watchDatabaseMirrorResponse
    /// Phone → watch: reply to `watchDatabaseMirrorChunk`, carrying `{index, chunkData}` for the
    /// requested chunk of the encoded `WatchDatabaseMirror`.
    case watchDatabaseMirrorChunkResponse
    /// Phone → watch: reply to `serversConfigSync`, carrying the servers (and any client
    /// certificates) inline.
    case serversConfigSyncResponse
    /// Phone → watch: acknowledgement that the client-certificate import screen will be presented.
    case clientCertImportRequestResponse
}
