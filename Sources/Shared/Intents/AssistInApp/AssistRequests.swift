import Foundation
import HAKit

public enum AssistRequests {
    public static func assistByVoiceTypedSubscription(
        preferredPipelineId: String,
        audioSampleRate: Double,
        conversationId: String?
    ) -> HATypedSubscription<AssistResponse> {
        var data: [String: Any] = [
            "pipeline": preferredPipelineId,
            "start_stage": "stt",
            "end_stage": "tts",
            "input": [
                "sample_rate": audioSampleRate,
            ],
        ]
        if let conversationId {
            data["conversation_id"] = conversationId
        }
        return .init(request: .init(type: .webSocket("assist_pipeline/run"), data: data))
    }

    public static func assistByTextTypedSubscription(
        preferredPipelineId: String,
        inputText: String,
        conversationId: String?
    ) -> HATypedSubscription<AssistResponse> {
        var data: [String: Any] = [
            "pipeline": preferredPipelineId,
            "start_stage": "intent",
            "end_stage": "intent",
            "input": [
                "text": inputText,
            ],
        ]
        if let conversationId {
            data["conversation_id"] = conversationId
        }
        return .init(request: .init(type: .webSocket("assist_pipeline/run"), data: data))
    }

    public static var fetchPipelinesTypedRequest: HATypedRequest<PipelineResponse> {
        .init(request: HARequest(type: .webSocket("assist_pipeline/pipeline/list")))
    }
}
