import Foundation

public enum InteractiveImmediateMessages: String, CaseIterable {
    case actionRowPressed = "ActionRowPressed"
    case pushAction = "PushAction"
    case assistPipelinesFetch = "AssistPipelinesFetch"
}

public enum InteractiveImmediateResponses: String, CaseIterable {
    case actionRowPressedResponse = "ActionRowPressedResponse"
    case assistPipelinesFetchResponse = "AssistPipelinesFetchResponse"
}
