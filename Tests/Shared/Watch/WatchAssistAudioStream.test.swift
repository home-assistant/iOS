import Foundation
@testable import Shared
import Testing

struct WatchAssistAudioStreamTests {
    /// Stands in for WatchConnectivity: keeps every message the stream sends so a test can answer
    /// it, or fail it, whenever it likes.
    private final class FakeLink {
        struct Sent {
            let message: HAWatchConnectivity.InteractiveImmediateMessage
            let timeout: TimeInterval
            let fail: (Error) -> Void
        }

        private(set) var sent: [Sent] = []

        func record(
            _ message: HAWatchConnectivity.InteractiveImmediateMessage,
            _ timeout: TimeInterval,
            _ fail: @escaping (Error) -> Void
        ) {
            sent.append(.init(message: message, timeout: timeout, fail: fail))
        }

        func sent(_ identifier: InteractiveImmediateMessages) -> [Sent] {
            sent.filter { $0.message.identifier == identifier.rawValue }
        }

        var chunks: [AssistAudioStreamChunkPayload] {
            sent(.assistAudioStreamChunk).compactMap { AssistAudioStreamChunkPayload(content: $0.message.content) }
        }

        func acknowledgeLast(isListening: Bool = true) throws {
            let last = try #require(sent.last)
            let streamId = try #require(last.message.content["streamId"] as? String)
            last.message.reply(.init(
                identifier: InteractiveImmediateResponses.assistAudioStreamAck.rawValue,
                content: AssistAudioStreamAckPayload(streamId: streamId, isListening: isListening).content
            ))
        }

        func failLast() throws {
            try #require(sent.last).fail(HAWatchConnectivity.ConnectivityError.replyTimedOut)
        }
    }

    /// What the stream told the recording.
    private final class Recorded {
        var stoppedRecording = 0
        var failures = 0
    }

    /// 0.2 s of 16 kHz 16-bit audio, the least a chunk waits for.
    private let minimumChunk = 6400

    private func makeStream(
        link: FakeLink,
        phoneSupportsStreaming: Bool = true,
        recorded: Recorded = Recorded()
    ) -> WatchAssistAudioStream {
        let stream = WatchAssistAudioStream(
            id: "stream",
            sampleRate: 16000,
            pipelineId: "pipeline",
            serverId: "server",
            phoneSupportsStreaming: phoneSupportsStreaming,
            send: link.record
        )
        stream.onStopRecording = { recorded.stoppedRecording += 1 }
        stream.onFailure = { _ in recorded.failures += 1 }
        stream.start()
        return stream
    }

    private func audio(_ count: Int, _ value: UInt8 = 1) -> Data {
        Data(repeating: value, count: count)
    }

    @Test func startsByTellingThePhoneWhatIsComing() throws {
        let link = FakeLink()
        _ = makeStream(link: link)

        let start = try #require(link.sent(.assistAudioStreamStart).first)
        #expect(AssistAudioStreamStartPayload(content: start.message.content) == AssistAudioStreamStartPayload(
            streamId: "stream",
            sampleRate: 16000,
            pipelineId: "pipeline",
            serverId: "server"
        ))
        // An iPhone that predates streaming never answers, so the wait for it is short.
        #expect(start.timeout == 5)
    }

    @Test func holdsTheAudioUntilThePhoneAcknowledgesTheStart() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)

        stream.append(audio(minimumChunk, 1))
        stream.append(audio(minimumChunk, 2))
        #expect(link.chunks.isEmpty)

        try link.acknowledgeLast()

        #expect(link.chunks == [AssistAudioStreamChunkPayload(
            streamId: "stream",
            sequence: 0,
            audio: audio(minimumChunk, 1) + audio(minimumChunk, 2),
            isFinal: false
        )])
    }

    /// One chunk is in flight at a time, and what is recorded meanwhile goes out together next.
    @Test func sendsTheNextChunkOnlyOnceThePreviousOneIsAcknowledged() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        try link.acknowledgeLast()

        stream.append(audio(minimumChunk, 1))
        stream.append(audio(minimumChunk, 2))
        stream.append(audio(minimumChunk, 3))
        #expect(link.chunks.map(\.audio) == [audio(minimumChunk, 1)])

        try link.acknowledgeLast()

        #expect(link.chunks.map(\.sequence) == [0, 1])
        #expect(link.chunks.last?.audio == audio(minimumChunk, 2) + audio(minimumChunk, 3))
    }

    @Test func waitsForEnoughAudioToFillAChunk() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        try link.acknowledgeLast()

        stream.append(audio(minimumChunk - 2))
        #expect(link.chunks.isEmpty)

        stream.append(audio(2))
        #expect(link.chunks.count == 1)
    }

    @Test func submittingSendsWhatIsLeftAsTheFinalChunk() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        try link.acknowledgeLast()
        stream.append(audio(10))

        #expect(stream.submit() == .sent)

        #expect(link.chunks == [AssistAudioStreamChunkPayload(
            streamId: "stream",
            sequence: 0,
            audio: audio(10),
            isFinal: true
        )])
        stream.append(audio(minimumChunk))
        try link.acknowledgeLast()
        #expect(link.chunks.count == 1)
    }

    @Test func splitsABacklogTooLargeForOneMessage() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        try link.acknowledgeLast()
        stream.append(audio(40000))
        _ = stream.submit()
        try link.acknowledgeLast()

        #expect(link.chunks.map(\.audio.count) == [32 * 1024, 40000 - 32 * 1024])
        #expect(link.chunks.map(\.isFinal) == [false, true])
    }

    @Test func uploadsTheWholeRecordingWhenThePhoneNeverAcknowledgesTheStart() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        stream.append(audio(minimumChunk, 1))

        try link.failLast()
        stream.append(audio(minimumChunk, 2))

        #expect(stream.submit() == .upload(audio(minimumChunk, 1) + audio(minimumChunk, 2)))
        #expect(link.chunks.isEmpty)
    }

    /// An answer that is not an acknowledgement — the counterpart's reply to an envelope it could
    /// not read is empty — says nothing about streaming, so the recording is kept whole.
    @Test func uploadsTheWholeRecordingWhenThePhonesAnswerCannotBeRead() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        stream.append(audio(minimumChunk, 1))

        try #require(link.sent.last).message.reply(.init(
            identifier: InteractiveImmediateResponses.assistAudioStreamAck.rawValue
        ))
        stream.append(audio(minimumChunk, 2))

        #expect(stream.submit() == .upload(audio(minimumChunk, 1) + audio(minimumChunk, 2)))
        #expect(link.chunks.isEmpty)
    }

    @Test func uploadsTheWholeRecordingToAPhoneThatPredatesStreaming() {
        let link = FakeLink()
        let stream = makeStream(link: link, phoneSupportsStreaming: false)
        stream.append(audio(minimumChunk))

        #expect(link.sent.isEmpty)
        #expect(stream.submit() == .upload(audio(minimumChunk)))
    }

    /// A late answer to the start must not stream a recording that was already uploaded whole.
    @Test func ignoresAStartAcknowledgedAfterTheRecordingWasUploaded() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        stream.append(audio(minimumChunk))

        #expect(stream.submit() == .upload(audio(minimumChunk)))
        try link.acknowledgeLast()

        #expect(link.chunks.isEmpty)
    }

    @Test func stopsRecordingWhenThePhoneStopsListening() throws {
        let link = FakeLink()
        let recorded = Recorded()
        let stream = makeStream(link: link, recorded: recorded)
        try link.acknowledgeLast()

        stream.phoneStoppedListening()
        stream.phoneStoppedListening()
        stream.append(audio(minimumChunk))

        #expect(recorded.stoppedRecording == 1)
        #expect(stream.submit() == .sent)
        #expect(link.chunks.isEmpty)
    }

    /// The acknowledgement says so too, in case the iPhone's own message about it never arrives.
    @Test func stopsRecordingWhenAnAcknowledgementSaysThePhoneStoppedListening() throws {
        let link = FakeLink()
        let recorded = Recorded()
        let stream = makeStream(link: link, recorded: recorded)
        try link.acknowledgeLast()
        stream.append(audio(minimumChunk))

        try link.acknowledgeLast(isListening: false)
        stream.append(audio(minimumChunk))

        #expect(recorded.stoppedRecording == 1)
        #expect(link.chunks.count == 1)
    }

    /// The iPhone could not start listening — an unknown server, say — and reports why separately.
    @Test func stopsRecordingWhenThePhoneRefusesTheStart() throws {
        let link = FakeLink()
        let recorded = Recorded()
        let stream = makeStream(link: link, recorded: recorded)
        stream.append(audio(minimumChunk))

        try link.acknowledgeLast(isListening: false)

        #expect(recorded.stoppedRecording == 1)
        #expect(stream.submit() == .sent)
    }

    @Test func reportsAChunkThePhoneNeverAcknowledgedAndDropsTheStream() throws {
        let link = FakeLink()
        let recorded = Recorded()
        let stream = makeStream(link: link, recorded: recorded)
        try link.acknowledgeLast()
        stream.append(audio(minimumChunk))

        try link.failLast()

        #expect(recorded.failures == 1)
        let cancel = try #require(link.sent(.assistAudioStreamCancel).first)
        #expect(AssistAudioStreamEndPayload(content: cancel.message.content)?.streamId == "stream")
    }

    @Test func cancellingTellsThePhoneToDropTheRun() throws {
        let link = FakeLink()
        let stream = makeStream(link: link)
        try link.acknowledgeLast()

        stream.cancel()
        stream.append(audio(minimumChunk))
        // A cancel the iPhone never gets leaves its run to time out on its own.
        try link.failLast()

        #expect(link.sent(.assistAudioStreamCancel).count == 1)
        #expect(link.chunks.isEmpty)
    }

    /// The start may already have reached the iPhone, which would otherwise keep a run waiting.
    @Test func cancellingBeforeTheStartIsAcknowledgedStillTellsThePhone() {
        let link = FakeLink()
        let stream = makeStream(link: link)

        stream.cancel()

        #expect(link.sent(.assistAudioStreamCancel).count == 1)
    }

    @Test func cancellingARecordingThatWasUploadedTellsThePhoneNothing() {
        let link = FakeLink()
        let stream = makeStream(link: link, phoneSupportsStreaming: false)

        stream.cancel()

        #expect(link.sent.isEmpty)
    }

    /// The rate is turned into a whole number on the iPhone, which traps for some values.
    @Test(arguments: [Double.nan, .infinity, -16000, 0, 1e300])
    func startWithASampleRateNoMicrophoneRecordsAtIsRejected(sampleRate: Double) {
        var content = AssistAudioStreamStartPayload(
            streamId: "s",
            sampleRate: 16000,
            pipelineId: "p",
            serverId: "h"
        ).content
        content["sampleRate"] = sampleRate

        #expect(AssistAudioStreamStartPayload(content: content) == nil)
    }

    @Test func payloadsSurviveTheRoundTripAndRejectMissingKeys() {
        let start = AssistAudioStreamStartPayload(streamId: "s", sampleRate: 16000, pipelineId: "p", serverId: "h")
        #expect(AssistAudioStreamStartPayload(content: start.content) == start)
        #expect(AssistAudioStreamStartPayload(content: ["streamId": "s"]) == nil)

        let chunk = AssistAudioStreamChunkPayload(streamId: "s", sequence: 3, audio: Data([1, 2]), isFinal: true)
        #expect(AssistAudioStreamChunkPayload(content: chunk.content) == chunk)
        #expect(AssistAudioStreamChunkPayload(content: ["streamId": "s", "sequence": 3]) == nil)

        let ack = AssistAudioStreamAckPayload(streamId: "s", isListening: false)
        #expect(AssistAudioStreamAckPayload(content: ack.content) == ack)
        #expect(AssistAudioStreamAckPayload(content: [:]) == nil)

        let end = AssistAudioStreamEndPayload(streamId: "s")
        #expect(AssistAudioStreamEndPayload(content: end.content) == end)
        #expect(AssistAudioStreamEndPayload(content: [:]) == nil)

        for payload in [start.content, chunk.content, ack.content, end.content] {
            #expect(PropertyListSerialization.propertyList(payload, isValidFor: .binary))
        }
    }
}
