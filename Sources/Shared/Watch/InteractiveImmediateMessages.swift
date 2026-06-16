import Foundation

public enum InteractiveImmediateMessages: String, CaseIterable {
    case ping
    case magicItemPressed
    case pushAction = "PushAction"
    case assistPipelinesFetch
    case assistAudioDataChunked
    case watchConfig
    /// Watch → phone: request the client certificate(s) (mTLS) it is missing locally.
    case clientCertExport
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
    /// Phone → watch: acknowledgement that the requested client certificate(s) are being sent (via Blob).
    case clientCertExportResponse
}

/// Identifiers for `Communicator` `Blob` transfers (used for larger payloads than messages allow).
public enum WatchBlob: String, CaseIterable {
    /// Phone → watch: the raw client certificate bundle(s) for mTLS, as encoded
    /// `[ClientCertificateTransferItem]`. The watch imports these into its own Keychain.
    case clientCertificates
}
