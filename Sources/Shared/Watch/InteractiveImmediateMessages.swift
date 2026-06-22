import Foundation

public enum InteractiveImmediateMessages: String, CaseIterable {
    case ping
    case magicItemPressed
    case pushAction = "PushAction"
    case assistPipelinesFetch
    case assistAudioDataChunked
    case watchConfig
    /// Watch → phone: ask the phone for the latest server configuration. The phone replies with the
    /// encoded servers and any mTLS client certificate bundles inline (see WatchCommunicatorService).
    case serversConfigSync
    /// Watch → phone: ask the phone to present the client-certificate (mTLS) import screen so the
    /// user can supply a `.p12` + password for the given server. The phone can't foreground itself,
    /// so the screen appears the next time the user opens the iPhone app.
    case clientCertImportRequest
}

public enum InteractiveImmediateResponses: String, CaseIterable {
    case pong
    case magicItemRowPressedResponse
    case pushActionResponse = "PushActionResponse"
    case assistPipelinesFetchResponse
    case assistAudioDataResponse
    case assistSTTResponse
    case assistIntentEndResponse
    case assistTTSResponse
    case assistError
    case watchConfigResponse
    case emptyWatchConfigResponse
    /// Phone → watch: reply to `serversConfigSync`, carrying the servers (and any client
    /// certificates) inline.
    case serversConfigSyncResponse
    /// Phone → watch: acknowledgement that the client-certificate import screen will be presented.
    case clientCertImportRequestResponse
}
