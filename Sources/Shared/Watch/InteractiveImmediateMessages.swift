import Foundation

public enum InteractiveImmediateMessages: String, CaseIterable {
    case actionRowPressed = "ActionRowPressed"
    case pushAction = "PushAction"
    case assistPipelinesFetch
    case assistAudioData
}

public enum InteractiveImmediateResponses: String, CaseIterable {
    case actionRowPressedResponse = "ActionRowPressedResponse"
    case pushActionResponse = "PushActionResponse"
    case assistPipelinesFetchResponse
    case assistAudioDataResponse
    case assistSTTResponse
    case assistIntentEndResponse
    case assistTTSResponse
    case assistError
}
