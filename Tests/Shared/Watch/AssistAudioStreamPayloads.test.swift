import Foundation
@testable import Shared
import Testing

struct AssistAudioStreamPayloadsTests {
    @Test func chunkPayloadRoundTrips() {
        let payload = AssistAudioStreamChunkPayload(
            recordingId: "rec",
            chunkIndex: 3,
            chunkData: Data([1, 2, 3]),
            sampleRate: 16000,
            pipelineId: "pipeline",
            serverId: "server"
        )

        let decoded = AssistAudioStreamChunkPayload(content: payload.content)
        #expect(decoded?.recordingId == "rec")
        #expect(decoded?.chunkIndex == 3)
        #expect(decoded?.chunkData == Data([1, 2, 3]))
        #expect(decoded?.sampleRate == 16000)
        #expect(decoded?.pipelineId == "pipeline")
        #expect(decoded?.serverId == "server")
    }

    @Test func chunkPayloadRejectsMissingRecordingId() {
        var content = AssistAudioStreamChunkPayload(
            recordingId: "rec",
            chunkIndex: 0,
            chunkData: Data(),
            sampleRate: 16000,
            pipelineId: "pipeline",
            serverId: "server"
        ).content
        content.removeValue(forKey: "recordingId")

        #expect(AssistAudioStreamChunkPayload(content: content) == nil)
    }

    @Test func chunkAckPayloadRoundTrips() {
        let stop = AssistAudioStreamChunkAckPayload(chunkIndex: 7, keepListening: false)
        let decoded = AssistAudioStreamChunkAckPayload(content: stop.content)
        #expect(decoded?.chunkIndex == 7)
        #expect(decoded?.keepListening == false)

        #expect(AssistAudioStreamChunkAckPayload(content: ["chunkIndex": 1]) == nil)
    }

    @Test func endPayloadRoundTrips() {
        let payload = AssistAudioStreamEndPayload(recordingId: "rec")
        #expect(AssistAudioStreamEndPayload(content: payload.content)?.recordingId == "rec")
        #expect(AssistAudioStreamEndPayload(content: [:]) == nil)
    }
}
