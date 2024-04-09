import Foundation
import HAKit

public enum AssistRequests {
    public static func assistByVoiceTypedSubscription(
        preferredPipelineId: String,
        audioSampleRate: Double
    ) -> HATypedSubscription<AssistResponse> {
        .init(request: .init(type: .webSocket("assist_pipeline/run"), data: [
            "pipeline": preferredPipelineId,
            "start_stage": "stt",
            "end_stage": "tts",
            "input": [
                "sample_rate": audioSampleRate,
            ],
        ]))
    }

    public static func assistByTextTypedSubscription(
        preferredPipelineId: String,
        inputText: String
    ) -> HATypedSubscription<AssistResponse> {
        .init(request: .init(type: .webSocket("assist_pipeline/run"), data: [
            "pipeline": preferredPipelineId,
            "start_stage": "intent",
            "end_stage": "intent",
            "input": [
                "text": inputText,
            ],
        ]))
    }

    public static var fetchPipelinesTypedRequest: HATypedRequest<PipelineResponse> {
        .init(request: HARequest(type: .webSocket("assist_pipeline/pipeline/list")))
    }
}
