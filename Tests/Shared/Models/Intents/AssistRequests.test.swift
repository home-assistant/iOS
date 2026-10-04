import Foundation
import HAKit
@testable import Shared
import Testing

/// The `assist_pipeline/run` payloads the in-app, watch and CarPlay Assist flows send.
struct AssistRequestsTests {
    @Test func voiceRunCarriesEveryOptionalKeyWhenProvided() throws {
        let request = AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: "pipeline-1",
            audioSampleRate: 16000,
            conversationId: "conversation-1",
            hassDeviceId: "device-1",
            tts: true
        ).request

        #expect(request.type == .webSocket("assist_pipeline/run"))
        #expect(request.data["start_stage"] as? String == "stt")
        #expect(request.data["end_stage"] as? String == "tts")
        let input = try #require(request.data["input"] as? [String: Any])
        #expect(input["sample_rate"] as? Double == 16000)
        #expect(request.data["pipeline"] as? String == "pipeline-1")
        #expect(request.data["conversation_id"] as? String == "conversation-1")
        #expect(request.data["device_id"] as? String == "device-1")
    }

    @Test func voiceRunWithoutTTSEndsAtIntentAndOmitsMissingKeys() {
        let request = AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: nil,
            audioSampleRate: 44100,
            conversationId: nil,
            hassDeviceId: nil,
            tts: false
        ).request

        #expect(request.data["end_stage"] as? String == "intent")
        #expect(request.data["pipeline"] == nil)
        #expect(request.data["conversation_id"] == nil)
        #expect(request.data["device_id"] == nil)
    }

    /// An empty id is how "Preferred" is stored, so it must leave the choice to the server.
    @Test func voiceRunTreatsEmptyPipelineIdAsPreferred() {
        let request = AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: "",
            audioSampleRate: 16000,
            conversationId: nil,
            hassDeviceId: nil,
            tts: true
        ).request

        #expect(request.data["pipeline"] == nil)
    }

    @Test func textRunCarriesEveryOptionalKeyWhenProvided() throws {
        let request = AssistRequests.assistByTextTypedSubscription(
            preferredPipelineId: "pipeline-2",
            inputText: "turn on the lights",
            conversationId: "conversation-2",
            hassDeviceId: "device-2",
            tts: true
        ).request

        #expect(request.type == .webSocket("assist_pipeline/run"))
        #expect(request.data["start_stage"] as? String == "intent")
        #expect(request.data["end_stage"] as? String == "tts")
        let input = try #require(request.data["input"] as? [String: Any])
        #expect(input["text"] as? String == "turn on the lights")
        #expect(request.data["pipeline"] as? String == "pipeline-2")
        #expect(request.data["conversation_id"] as? String == "conversation-2")
        #expect(request.data["device_id"] as? String == "device-2")
    }

    @Test func textRunWithoutTTSEndsAtIntentAndOmitsMissingKeys() {
        let request = AssistRequests.assistByTextTypedSubscription(
            preferredPipelineId: "",
            inputText: "hello",
            conversationId: nil,
            hassDeviceId: nil,
            tts: false
        ).request

        #expect(request.data["end_stage"] as? String == "intent")
        #expect(request.data["pipeline"] == nil)
        #expect(request.data["conversation_id"] == nil)
        #expect(request.data["device_id"] == nil)
    }

    @Test func fetchPipelinesUsesThePipelineListCommand() {
        let request = AssistRequests.fetchPipelinesTypedRequest.request

        #expect(request.type == .webSocket("assist_pipeline/pipeline/list"))
        #expect(request.data.isEmpty)
    }
}
