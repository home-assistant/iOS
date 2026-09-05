import Foundation
@testable import Shared
import Testing

/// Captures every interactive send so a test can answer (or fail) it whenever it likes.
private final class FakeAssistAudioStreamSender: WatchAssistAudioStreamSending {
    struct Sent {
        let message: HAWatchConnectivity.InteractiveImmediateMessage
        let errorHandler: (Error) -> Void

        var identifier: String { message.identifier }
        var chunk: AssistAudioStreamChunkPayload? { AssistAudioStreamChunkPayload(content: message.content) }
    }

    private(set) var sent: [Sent] = []

    func sendAssistAudioStreamMessage(
        _ message: HAWatchConnectivity.InteractiveImmediateMessage,
        errorHandler: @escaping (Error) -> Void
    ) {
        sent.append(Sent(message: message, errorHandler: errorHandler))
    }

    func acknowledge(_ index: Int, keepListening: Bool = true) {
        let entry = sent[index]
        entry.message.reply(.init(
            identifier: InteractiveImmediateResponses.assistAudioStreamChunkAck.rawValue,
            content: AssistAudioStreamChunkAckPayload(
                chunkIndex: entry.chunk?.chunkIndex ?? -1,
                keepListening: keepListening
            ).content
        ))
    }
}

private struct FakeDeliveryError: Error {}

struct WatchAssistAudioStreamerTests {
    private let sender = FakeAssistAudioStreamSender()
    private let chunkIdentifier = InteractiveImmediateMessages.assistAudioStreamChunk.rawValue
    private let endIdentifier = InteractiveImmediateMessages.assistAudioStreamEnd.rawValue

    private func makeStreamer() -> WatchAssistAudioStreamer {
        WatchAssistAudioStreamer(
            recordingId: "rec-1",
            serverId: "server",
            pipelineId: "pipeline",
            sampleRate: 16000,
            sender: sender
        )
    }

    private func audio(_ bytes: Int, fill: UInt8 = 1) -> Data {
        Data(repeating: fill, count: bytes)
    }

    @Test func firstChunkWaitsForMinimumAudioThenCarriesRecordingDetails() {
        let streamer = makeStreamer()

        streamer.enqueue(audio: audio(WatchAssistAudioStreamer.Constants.minChunkBytes - 1))
        #expect(sender.sent.isEmpty)

        streamer.enqueue(audio: audio(1))
        #expect(sender.sent.count == 1)
        let chunk = sender.sent[0].chunk
        #expect(sender.sent[0].identifier == chunkIdentifier)
        #expect(chunk?.recordingId == "rec-1")
        #expect(chunk?.serverId == "server")
        #expect(chunk?.pipelineId == "pipeline")
        #expect(chunk?.sampleRate == 16000)
        #expect(chunk?.chunkIndex == 0)
        #expect(chunk?.chunkData.count == WatchAssistAudioStreamer.Constants.minChunkBytes)
    }

    @Test func audioCapturedWhileAChunkIsInFlightGoesOutTogetherAfterTheAck() {
        let streamer = makeStreamer()
        let minimum = WatchAssistAudioStreamer.Constants.minChunkBytes

        streamer.enqueue(audio: audio(minimum, fill: 1))
        streamer.enqueue(audio: audio(minimum, fill: 2))
        streamer.enqueue(audio: audio(minimum, fill: 3))
        #expect(sender.sent.count == 1)

        sender.acknowledge(0)
        #expect(sender.sent.count == 2)
        let second = sender.sent[1].chunk
        #expect(second?.chunkIndex == 1)
        #expect(second?.chunkData == audio(minimum, fill: 2) + audio(minimum, fill: 3))

        // Nothing is buffered any more, so the ack does not trigger another send.
        sender.acknowledge(1)
        #expect(sender.sent.count == 2)
    }

    @Test func aChunkNeverExceedsTheMessageCeiling() {
        let streamer = makeStreamer()
        let maximum = WatchAssistAudioStreamer.Constants.maxChunkBytes

        streamer.enqueue(audio: audio(maximum + 100))
        #expect(sender.sent[0].chunk?.chunkData.count == maximum)

        sender.acknowledge(0)
        // The remainder is below the minimum, so it waits for more audio or for the end.
        #expect(sender.sent.count == 1)
        streamer.end()
        #expect(sender.sent.count == 3)
        #expect(sender.sent[1].chunk?.chunkData.count == 100)
        #expect(sender.sent[1].chunk?.chunkIndex == 1)
        #expect(sender.sent[2].identifier == endIdentifier)
    }

    @Test func stopFromThePhoneDropsBufferedAudioAndEndsTheStream() {
        let streamer = makeStreamer()
        var stops = 0
        streamer.onStopListening = { stops += 1 }

        streamer.enqueue(audio: audio(WatchAssistAudioStreamer.Constants.minChunkBytes))
        streamer.enqueue(audio: audio(500))
        sender.acknowledge(0, keepListening: false)

        #expect(stops == 1)
        #expect(streamer.phase == .ended)
        #expect(sender.sent.count == 2)
        #expect(sender.sent[1].identifier == endIdentifier)
        #expect(AssistAudioStreamEndPayload(content: sender.sent[1].message.content)?.recordingId == "rec-1")

        // The recorder stops and reports the end: nothing more goes out, and no second callback.
        streamer.enqueue(audio: audio(5000))
        streamer.end()
        #expect(sender.sent.count == 2)
        #expect(stops == 1)
    }

    @Test func endFlushesTheRemainderBeforeTheEndMessage() {
        let streamer = makeStreamer()

        streamer.enqueue(audio: audio(WatchAssistAudioStreamer.Constants.minChunkBytes))
        streamer.enqueue(audio: audio(300))
        streamer.end()
        // The first chunk is still in flight: the remainder waits for its ack.
        #expect(sender.sent.count == 1)
        #expect(streamer.phase == .ending)

        sender.acknowledge(0)
        #expect(sender.sent.count == 3)
        #expect(sender.sent[1].chunk?.chunkData.count == 300)
        #expect(sender.sent[2].identifier == endIdentifier)
        #expect(streamer.phase == .ended)
    }

    @Test func endWithoutAnyAudioSendsOnlyTheEndMessage() {
        let streamer = makeStreamer()

        streamer.end()
        #expect(sender.sent.count == 1)
        #expect(sender.sent[0].identifier == endIdentifier)
        #expect(streamer.phase == .ended)
    }

    @Test func aReplyWithoutAnAckPayloadKeepsStreaming() {
        let streamer = makeStreamer()
        var stops = 0
        streamer.onStopListening = { stops += 1 }

        streamer.enqueue(audio: audio(WatchAssistAudioStreamer.Constants.minChunkBytes))
        sender.sent[0].message.reply(.init(identifier: "something-else"))

        #expect(stops == 0)
        #expect(streamer.phase == .streaming)
        streamer.enqueue(audio: audio(WatchAssistAudioStreamer.Constants.minChunkBytes))
        #expect(sender.sent.count == 2)
    }

    @Test func deliveryFailureEndsTheStreamAndReportsOnce() {
        let streamer = makeStreamer()
        var errors: [Error] = []
        streamer.onError = { errors.append($0) }

        streamer.enqueue(audio: audio(WatchAssistAudioStreamer.Constants.minChunkBytes))
        sender.sent[0].errorHandler(FakeDeliveryError())

        #expect(errors.count == 1)
        #expect(streamer.phase == .ended)
        // Neither more audio nor the end goes out on a dead stream.
        streamer.enqueue(audio: audio(WatchAssistAudioStreamer.Constants.minChunkBytes))
        streamer.end()
        #expect(sender.sent.count == 1)
        #expect(errors.count == 1)
    }
}
