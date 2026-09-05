import Foundation
@testable import HomeAssistant
import Testing

/// What the relay asked of the pipeline, in order: each forwarded chunk, and "finish" once the
/// audio was declared complete.
private final class PipelineCallLog {
    private(set) var calls: [String] = []

    func makeStream(recordingId: String = "rec", now: Date = Date()) -> WatchAssistAudioStream {
        WatchAssistAudioStream(
            recordingId: recordingId,
            now: now,
            sendAudio: { [weak self] data in self?.calls.append("audio:\(data.count)") },
            finishAudio: { [weak self] in self?.calls.append("finish") }
        )
    }
}

struct WatchAssistAudioStreamTests {
    private let log = PipelineCallLog()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func chunksBeforeTheGreenLightAreFlushedInOrderAfterIt() {
        let stream = log.makeStream()

        #expect(stream.receive(chunk: Data(count: 1), now: now))
        #expect(stream.receive(chunk: Data(count: 2), now: now))
        #expect(log.calls.isEmpty)

        stream.pipelineDidStartAcceptingAudio()
        #expect(log.calls == ["audio:1", "audio:2"])

        #expect(stream.receive(chunk: Data(count: 3), now: now))
        #expect(log.calls == ["audio:1", "audio:2", "audio:3"])
        #expect(!stream.isFinished)
    }

    @Test func pipelineStoppingListeningFinishesTheAudioOnceAndTellsTheWatchToStop() {
        let stream = log.makeStream()
        stream.pipelineDidStartAcceptingAudio()
        #expect(stream.receive(chunk: Data(count: 1), now: now))

        stream.pipelineDidStopListening()
        #expect(log.calls == ["audio:1", "finish"])
        #expect(stream.isFinished)

        // The watch sends one more chunk before it hears the stop: it is dropped, and the ack
        // says stop.
        #expect(!stream.receive(chunk: Data(count: 2), now: now))
        stream.pipelineDidStopListening()
        stream.watchDidEnd()
        #expect(log.calls == ["audio:1", "finish"])
    }

    @Test func watchEndingAfterTheGreenLightFinishesTheAudio() {
        let stream = log.makeStream()
        stream.pipelineDidStartAcceptingAudio()
        #expect(stream.receive(chunk: Data(count: 4), now: now))

        stream.watchDidEnd()
        #expect(log.calls == ["audio:4", "finish"])

        // A late pipeline event must not finish twice.
        stream.pipelineDidStopListening()
        #expect(log.calls == ["audio:4", "finish"])
    }

    @Test func watchEndingBeforeTheGreenLightFinishesRightAfterTheFlush() {
        let stream = log.makeStream()
        #expect(stream.receive(chunk: Data(count: 5), now: now))
        stream.watchDidEnd()
        #expect(log.calls.isEmpty)
        #expect(!stream.isFinished)

        stream.pipelineDidStartAcceptingAudio()
        #expect(log.calls == ["audio:5", "finish"])
        #expect(stream.isFinished)

        // Chunks after the end are refused.
        #expect(!stream.receive(chunk: Data(count: 6), now: now))
        #expect(log.calls == ["audio:5", "finish"])
    }

    @Test func failureBeforeTheGreenLightNeverFinishesAudio() {
        let stream = log.makeStream()
        #expect(stream.receive(chunk: Data(count: 1), now: now))

        stream.pipelineDidStopListening()
        #expect(!stream.receive(chunk: Data(count: 2), now: now))
        stream.pipelineDidStartAcceptingAudio()
        #expect(log.calls.isEmpty)
        #expect(!stream.isFinished)
    }

    @Test func lastChunkTimeFollowsTheChunks() {
        let stream = log.makeStream(now: now)
        #expect(stream.lastChunkAt == now)

        let later = now.addingTimeInterval(3)
        _ = stream.receive(chunk: Data(count: 1), now: later)
        #expect(stream.lastChunkAt == later)
    }
}
