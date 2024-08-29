import Foundation
import HAKit

public enum AssistRequests {
    static var runCommand = "assist_pipeline/run"
    public static func assistByVoiceTypedSubscription(
        preferredPipelineId: String?,
        audioSampleRate: Double,
        conversationId: String?,
        hassDeviceId: String?
    ) -> HATypedSubscription<AssistResponse> {
        var data: [String: Any] = [
            "start_stage": "stt",
            "end_stage": "tts",
            "input": [
                "sample_rate": audioSampleRate,
            ],
        ]
        if let preferredPipelineId {
            data["pipeline"] = preferredPipelineId
        }
        if let conversationId {
            data["conversation_id"] = conversationId
        }
        if let hassDeviceId {
            data["device_id"] = hassDeviceId
        }
        return .init(request: .init(type: .webSocket(runCommand), data: data))
    }

    public static func assistByTextTypedSubscription(
        preferredPipelineId: String?,
        inputText: String,
        conversationId: String?,
        hassDeviceId: String?
    ) -> HATypedSubscription<AssistResponse> {
        var data: [String: Any] = [
            "start_stage": "intent",
            "end_stage": "intent",
            "input": [
                "text": inputText,
            ],
        ]
        if let preferredPipelineId {
            data["pipeline"] = preferredPipelineId
        }
        if let conversationId {
            data["conversation_id"] = conversationId
        }
        if let hassDeviceId {
            data["device_id"] = hassDeviceId
        }
        return .init(request: .init(type: .webSocket(runCommand), data: data))
    }

    public static var fetchPipelinesTypedRequest: HATypedRequest<PipelineResponse> {
        .init(request: HARequest(type: .webSocket("assist_pipeline/pipeline/list")))
    }
}
