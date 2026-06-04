import Foundation

public enum InteractiveImmediateMessages: String, CaseIterable {
    case ping
    case magicItemPressed
    case pushAction = "PushAction"
    case assistPipelinesFetch
    case assistAudioDataChunked
    case watchConfig
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
}
