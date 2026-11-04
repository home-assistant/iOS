import AVFoundation
@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class WatchCommunicatorAssistTests: XCTestCase {
    private var server: Server!
    private var previousServers: ServerManager!
    private var assistService: MockAssistService!
    private var recognizer: FakeSpeechRecognizer!
    private var recognizerLocale: Locale?
    private var recognizerFailure: Error?
    private var configuration = AssistConfiguration()
    private var watchSpeaksOnDevice = true
    private var watchReadsResponsesFromPong = true
    private var watchUnreachable = false
    private var failsLater = false
    private var lateFailures: [() -> Void] = []
    private var sentMessages: [HAWatchConnectivity.ImmediateMessage] = []
    private var streamReplies: [HAWatchConnectivity.ImmediateMessage] = []
    private var service: WatchCommunicatorService!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        assistService = MockAssistService()
        recognizer = FakeSpeechRecognizer()
        recognizerLocale = nil
        recognizerFailure = nil
        configuration = AssistConfiguration()
        watchSpeaksOnDevice = true
        watchReadsResponsesFromPong = true
        watchUnreachable = false
        failsLater = false
        lateFailures = []
        sentMessages = []
        streamReplies = []

        service = WatchCommunicatorService()
        service.assistConfiguration = { [weak self] in self?.configuration ?? AssistConfiguration() }
        service.makeAssistService = { [weak self] _ in self?.assistService ?? MockAssistService() }
        service.makeSpeechRecognizer = { [weak self] locale in
            self?.recognizerLocale = locale
            if let failure = self?.recognizerFailure {
                throw failure
            }
            return self?.recognizer ?? FakeSpeechRecognizer()
        }
        service.send = { [weak self] message, failed in
            guard let self else { return }
            if failsLater {
                lateFailures.append { failed(HAWatchConnectivity.ConnectivityError.replyTimedOut) }
            } else if watchUnreachable {
                failed(HAWatchConnectivity.ConnectivityError.notReachable)
            } else {
                sentMessages.append(message)
            }
        }
        service.watchSpeaksOnDevice = { [weak self] in self?.watchSpeaksOnDevice ?? true }
        service.watchReadsAssistResponsesFromPong = { [weak self] in self?.watchReadsResponsesFromPong ?? true }
    }

    override func tearDown() {
        Current.servers = previousServers
        super.tearDown()
    }

    // MARK: - Helpers

    private let audioData = Data([0x52, 0x49, 0x46, 0x46])

    private func sendRecording() {
        let payload = AssistAudioChunkPayload(
            chunkData: audioData,
            chunkIndex: 0,
            totalChunks: 1,
            sampleRate: 16000,
            pipelineId: "pipeline",
            serverId: server.identifier.rawValue,
            recordingId: "recording"
        )
        service.handleAssistAudioChunkedMessage(.init(
            identifier: InteractiveImmediateMessages.assistAudioDataChunked.rawValue,
            content: payload.content,
            reply: { _ in }
        ))
    }

    private func sendPrompt(_ text: String) {
        let payload = AssistTextInputPayload(text: text, pipelineId: "pipeline", serverId: server.identifier.rawValue)
        service.handleAssistTextInputMessage(.init(
            identifier: InteractiveImmediateMessages.assistTextInput.rawValue,
            content: payload.content,
            reply: { _ in }
        ))
    }

    private func startStream(_ streamId: String = "stream", serverId: String? = nil) {
        let payload = AssistAudioStreamStartPayload(
            streamId: streamId,
            sampleRate: 16000,
            pipelineId: "pipeline",
            serverId: serverId ?? server.identifier.rawValue
        )
        service.handleAssistAudioStreamStart(.init(
            identifier: InteractiveImmediateMessages.assistAudioStreamStart.rawValue,
            content: payload.content,
            reply: { [weak self] in self?.streamReplies.append($0) }
        ))
    }

    private func streamChunk(_ audio: Data, sequence: Int, isFinal: Bool = false, streamId: String = "stream") {
        let payload = AssistAudioStreamChunkPayload(
            streamId: streamId,
            sequence: sequence,
            audio: audio,
            isFinal: isFinal
        )
        service.handleAssistAudioStreamChunk(.init(
            identifier: InteractiveImmediateMessages.assistAudioStreamChunk.rawValue,
            content: payload.content,
            reply: { [weak self] in self?.streamReplies.append($0) }
        ))
    }

    private func cancelStream(_ streamId: String = "stream") {
        service.handleAssistAudioStreamCancel(.init(
            identifier: InteractiveImmediateMessages.assistAudioStreamCancel.rawValue,
            content: AssistAudioStreamEndPayload(streamId: streamId).content,
            reply: { [weak self] in self?.streamReplies.append($0) }
        ))
    }

    private var acks: [AssistAudioStreamAckPayload] {
        streamReplies.compactMap { AssistAudioStreamAckPayload(content: $0.content) }
    }

    private var stoppedStreams: [String] {
        messages(.assistAudioStreamStop).compactMap { AssistAudioStreamEndPayload(content: $0.content)?.streamId }
    }

    private func messages(_ response: InteractiveImmediateResponses) -> [HAWatchConnectivity.ImmediateMessage] {
        sentMessages.filter { $0.identifier == response.rawValue }
    }

    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 1)
    }

    private func ping() -> [(identifier: String, content: [String: Any])] {
        flushMainQueue()
        var pong: HAWatchConnectivity.ImmediateMessage?
        service.handlePing(.init(identifier: InteractiveImmediateMessages.ping.rawValue, reply: { pong = $0 }))
        XCTAssertEqual(pong?.identifier, InteractiveImmediateResponses.pong.rawValue)
        return PongPayload(content: pong?.content ?? [:]).assistMessages
    }

    private func waitUntil(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), "timed out waiting for the phone to finish the assist run")
    }

    // MARK: - Server speech-to-text

    func testRecordingRunsServerSTTAndRequestsServerTTSByDefault() {
        sendRecording()

        XCTAssertEqual(
            assistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: true)
        )
        XCTAssertFalse(recognizer.didReceiveAudio)

        service.didReceiveGreenLightForAudioInput()
        XCTAssertEqual(assistService.audioDataSent, audioData)
        XCTAssertTrue(assistService.finishSendingAudioCalled)
    }

    func testRecordingSkipsServerTTSWhenTTSIsOnDevice() {
        configuration = AssistConfiguration(enableOnDeviceTTS: true)

        sendRecording()

        XCTAssertEqual(
            assistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: false)
        )
    }

    func testRecordingKeepsServerTTSWhenTheWatchCannotSpeakOnDevice() {
        configuration = AssistConfiguration(enableOnDeviceTTS: true)
        watchSpeaksOnDevice = false

        sendRecording()

        XCTAssertEqual(
            assistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: true)
        )
    }

    func testRecordingSkipsServerTTSWhenMuted() {
        configuration = AssistConfiguration(muteTTS: true)

        sendRecording()

        XCTAssertEqual(
            assistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: false)
        )
    }

    // MARK: - On-device speech-to-text

    func testRecordingIsTranscribedOnThePhoneWhenSTTIsOnDevice() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true, onDeviceSTTLocaleIdentifier: "pt-BR")
        recognizer.finalTranscript = " Turn on the lights "

        sendRecording()
        waitUntil { assistService.assistSource != nil }

        XCTAssertEqual(recognizerLocale?.identifier, "pt-BR")
        XCTAssertTrue(recognizer.didReceiveAudio)
        XCTAssertTrue(recognizer.didEndAudio)
        XCTAssertEqual(
            assistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "pipeline", expectTTS: true)
        )
        XCTAssertFalse(assistService.sendAudioDataCalled)

        let echoed = messages(.assistSTTResponse).compactMap { AssistTextResponsePayload(content: $0.content) }
        XCTAssertEqual(echoed.map(\.text), ["Turn on the lights"])
    }

    func testOnDeviceTranscriptRunSkipsServerTTSWhenTTSIsOnDevice() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true, enableOnDeviceTTS: true)
        recognizer.finalTranscript = "Turn on the lights"

        sendRecording()
        waitUntil { assistService.assistSource != nil }

        XCTAssertEqual(
            assistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "pipeline", expectTTS: false)
        )
    }

    func testEmptyTranscriptReportsNoSpeechToTheWatch() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true)
        recognizer.finalTranscript = "   "

        sendRecording()
        waitUntil { !messages(.assistError).isEmpty }

        let errors = messages(.assistError).compactMap { AssistErrorPayload(content: $0.content) }
        XCTAssertEqual(errors.map(\.code), ["no_speech_recognized"])
        XCTAssertEqual(errors.map(\.message), [L10n.Assist.Watch.OnDeviceStt.noSpeechRecognized])
        XCTAssertNil(assistService.assistSource)
    }

    func testRecognizerFailureReportsTheErrorToTheWatch() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true)
        recognizer.failure = FakeSpeechRecognizer.TestError()

        sendRecording()
        waitUntil { !messages(.assistError).isEmpty }

        let errors = messages(.assistError).compactMap { AssistErrorPayload(content: $0.content) }
        XCTAssertEqual(errors.map(\.code), ["on_device_stt_failed"])
        XCTAssertEqual(errors.map(\.message), ["The recognizer is asleep"])
        XCTAssertNil(assistService.assistSource)
    }

    func testUnavailableRecognizerReportsTheErrorToTheWatch() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true)
        recognizerFailure = WyomingProtocolError.speechRecognitionNotAuthorized

        sendRecording()
        waitUntil { !messages(.assistError).isEmpty }

        let errors = messages(.assistError).compactMap { AssistErrorPayload(content: $0.content) }
        XCTAssertEqual(errors.map(\.code), ["on_device_stt_failed"])
        XCTAssertEqual(
            errors.map(\.message),
            [WyomingProtocolError.speechRecognitionNotAuthorized.errorDescription]
        )
        XCTAssertNil(assistService.assistSource)
    }

    // MARK: - Streamed recordings

    func testStreamStartsTheServerSTTRunBeforeAnyAudioArrives() {
        startStream()

        XCTAssertEqual(
            assistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: true)
        )
        XCTAssertEqual(acks, [AssistAudioStreamAckPayload(streamId: "stream", isListening: true)])
    }

    func testStreamedAudioWaitsForThePipelineAndThenGoesStraightThrough() {
        startStream()
        streamChunk(Data([1, 2]), sequence: 0)
        streamChunk(Data([3, 4]), sequence: 1)
        XCTAssertTrue(assistService.audioChunksSent.isEmpty)

        service.didReceiveGreenLightForAudioInput()
        streamChunk(Data([5, 6]), sequence: 2)

        XCTAssertEqual(assistService.audioChunksSent, [Data([1, 2, 3, 4]), Data([5, 6])])
        XCTAssertFalse(assistService.finishSendingAudioCalled)
        XCTAssertEqual(acks.map(\.isListening), [true, true, true, true])
    }

    func testRepeatedChunkIsNotSentTwice() {
        startStream()
        service.didReceiveGreenLightForAudioInput()

        streamChunk(Data([1, 2]), sequence: 0)
        streamChunk(Data([1, 2]), sequence: 0)

        XCTAssertEqual(assistService.audioChunksSent, [Data([1, 2])])
    }

    func testPipelineHearingTheEndOfSpeechStopsTheWatchRecording() {
        startStream()
        service.didReceiveGreenLightForAudioInput()
        streamChunk(Data([1, 2]), sequence: 0)

        service.didReceiveEvent(.sttVadEnd)

        XCTAssertEqual(stoppedStreams, ["stream"])
        XCTAssertTrue(assistService.finishSendingAudioCalled)

        // A chunk already on its way is answered as no longer wanted.
        streamChunk(Data([3, 4]), sequence: 1)
        XCTAssertEqual(acks.last, AssistAudioStreamAckPayload(streamId: "stream", isListening: false))
        XCTAssertEqual(assistService.audioChunksSent, [Data([1, 2])])

        service.didReceiveEvent(.sttEnd)
        XCTAssertEqual(stoppedStreams, ["stream"])
    }

    func testRunEndingWhileStreamingStopsTheWatchRecording() {
        startStream()
        service.didReceiveGreenLightForAudioInput()

        service.didReceiveEvent(.runEnd)

        XCTAssertEqual(stoppedStreams, ["stream"])
    }

    func testSubmittedStreamEndsTheAudioWithoutStoppingTheWatch() {
        startStream()
        service.didReceiveGreenLightForAudioInput()

        streamChunk(Data([1, 2]), sequence: 0, isFinal: true)

        XCTAssertEqual(assistService.audioChunksSent, [Data([1, 2])])
        XCTAssertTrue(assistService.finishSendingAudioCalled)
        XCTAssertEqual(acks.last?.isListening, false)
        service.didReceiveEvent(.sttVadEnd)
        XCTAssertTrue(stoppedStreams.isEmpty)
    }

    func testStreamSubmittedBeforeThePipelineIsReadyEndsOnceItIs() {
        startStream()
        streamChunk(Data([1, 2]), sequence: 0)
        streamChunk(Data(), sequence: 1, isFinal: true)
        XCTAssertFalse(assistService.finishSendingAudioCalled)

        service.didReceiveGreenLightForAudioInput()

        XCTAssertEqual(assistService.audioChunksSent, [Data([1, 2])])
        XCTAssertTrue(assistService.finishSendingAudioCalled)
    }

    func testCancelledStreamAbandonsTheRunInsteadOfFinishingIt() {
        startStream()
        service.didReceiveGreenLightForAudioInput()

        cancelStream()
        streamChunk(Data([1, 2]), sequence: 0)

        XCTAssertTrue(assistService.cancelRunCalled)
        XCTAssertFalse(assistService.finishSendingAudioCalled)
        XCTAssertTrue(assistService.audioChunksSent.isEmpty)
        XCTAssertEqual(acks.last, AssistAudioStreamAckPayload(streamId: "stream", isListening: false))
    }

    /// The service holds one run at a time: the previous question's late events would otherwise end
    /// the new stream's run.
    func testNewStreamAbandonsThePreviousRun() {
        startStream("first")
        XCTAssertFalse(assistService.cancelRunCalled)

        startStream("second")
        streamChunk(Data([1, 2]), sequence: 0, streamId: "first")

        XCTAssertTrue(assistService.cancelRunCalled)
        XCTAssertEqual(acks.last, AssistAudioStreamAckPayload(streamId: "first", isListening: false))
    }

    func testStreamTheWatchStopsFeedingIsAbandoned() {
        service.assistAudioStreamTimeout = 0.05
        startStream()

        waitUntil { assistService.cancelRunCalled }

        // The watch may still be recording, to send the recording whole once it is done.
        XCTAssertTrue(messages(.assistError).isEmpty)
    }

    func testSubmittedStreamThePipelineNeverTakesIsReportedToTheWatch() {
        service.assistAudioStreamTimeout = 0.05
        startStream()
        streamChunk(Data([1, 2]), sequence: 0, isFinal: true)

        waitUntil { assistService.cancelRunCalled }

        let errors = messages(.assistError).compactMap { AssistErrorPayload(content: $0.content) }
        XCTAssertEqual(errors.map(\.code), ["audio_stream_timeout"])
    }

    func testPipelineErrorEndsTheStream() {
        startStream()

        service.didReceiveError(code: "stt-provider-missing", message: "No speech-to-text provider")
        streamChunk(Data([1, 2]), sequence: 0)

        XCTAssertEqual(acks.last?.isListening, false)
        XCTAssertFalse(assistService.cancelRunCalled)
    }

    func testStreamToAnUnknownServerReportsTheErrorAndDoesNotListen() {
        startStream(serverId: "unknown")

        XCTAssertNil(assistService.assistSource)
        let errors = messages(.assistError).compactMap { AssistErrorPayload(content: $0.content) }
        XCTAssertEqual(errors.map(\.code), ["unknown_server"])
        XCTAssertEqual(acks, [AssistAudioStreamAckPayload(streamId: "stream", isListening: false)])
    }

    func testUnreadableStreamMessagesAreStillAnswered() {
        func unreadable(_ identifier: InteractiveImmediateMessages) -> HAWatchConnectivity.InteractiveImmediateMessage {
            .init(identifier: identifier.rawValue, content: [:], reply: { [weak self] in
                self?.streamReplies.append($0)
            })
        }

        service.handleAssistAudioStreamStart(unreadable(.assistAudioStreamStart))
        service.handleAssistAudioStreamChunk(unreadable(.assistAudioStreamChunk))
        service.handleAssistAudioStreamCancel(unreadable(.assistAudioStreamCancel))

        XCTAssertEqual(streamReplies.count, 3)
        XCTAssertTrue(acks.isEmpty)
        let errors = messages(.assistError).compactMap { AssistErrorPayload(content: $0.content) }
        XCTAssertEqual(errors.map(\.code), ["invalid_payload"])
    }

    func testUnreadableStreamStartLeavesTheStreamInProgressAlone() {
        startStream()

        service.handleAssistAudioStreamStart(.init(
            identifier: InteractiveImmediateMessages.assistAudioStreamStart.rawValue,
            content: [:],
            reply: { _ in }
        ))
        streamChunk(Data([1, 2]), sequence: 0)

        XCTAssertEqual(acks.last, AssistAudioStreamAckPayload(streamId: "stream", isListening: true))
    }

    func testWholeRecordingFromAWatchThatGaveUpStreamingReplacesTheStream() {
        startStream()

        sendRecording()
        service.didReceiveGreenLightForAudioInput()

        XCTAssertTrue(assistService.cancelRunCalled)
        XCTAssertEqual(assistService.audioChunksSent, [audioData])
        XCTAssertTrue(assistService.finishSendingAudioCalled)
    }

    func testStreamMessagesReachTheirHandlersThroughTheMessageRouter() {
        service.setupMessages()

        route(.assistAudioStreamStart, AssistAudioStreamStartPayload(
            streamId: "stream",
            sampleRate: 16000,
            pipelineId: "pipeline",
            serverId: server.identifier.rawValue
        ).content)
        route(.assistAudioStreamChunk, AssistAudioStreamChunkPayload(
            streamId: "stream",
            sequence: 0,
            audio: Data([1, 2]),
            isFinal: false
        ).content)
        route(.assistAudioStreamCancel, AssistAudioStreamEndPayload(streamId: "stream").content)

        XCTAssertEqual(
            assistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: true)
        )
        XCTAssertTrue(assistService.cancelRunCalled)
    }

    /// Delivers a message the way the watch's arrive. Every listener gets it on the main queue, so
    /// once the queue is flushed this service has handled it.
    private func route(_ identifier: InteractiveImmediateMessages, _ content: [String: Any]) {
        Communicator.shared.interactiveImmediateMessage.notify(.init(
            identifier: identifier.rawValue,
            content: content,
            reply: { _ in }
        ))
        flushMainQueue()
    }

    func testChunkAfterAGapIsStillSent() {
        startStream()
        service.didReceiveGreenLightForAudioInput()

        streamChunk(Data([1, 2]), sequence: 0)
        streamChunk(Data([5, 6]), sequence: 2)

        XCTAssertEqual(assistService.audioChunksSent, [Data([1, 2]), Data([5, 6])])
    }

    // MARK: - Streamed recordings, on-device speech-to-text

    func testStreamIsTranscribedOnThePhoneWhenSTTIsOnDevice() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true, onDeviceSTTLocaleIdentifier: "pt-BR")
        recognizer.finalTranscript = " Turn on the lights "

        startStream()
        streamChunk(Data([1, 2]), sequence: 0)
        XCTAssertTrue(recognizer.didReceiveAudio)
        XCTAssertNil(assistService.assistSource)
        XCTAssertEqual(acks.last?.isListening, true)

        streamChunk(Data([3, 4]), sequence: 1, isFinal: true)
        waitUntil { assistService.assistSource != nil }

        XCTAssertEqual(recognizerLocale?.identifier, "pt-BR")
        XCTAssertTrue(recognizer.didEndAudio)
        XCTAssertEqual(
            assistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "pipeline", expectTTS: true)
        )
        XCTAssertFalse(assistService.sendAudioDataCalled)
        XCTAssertTrue(stoppedStreams.isEmpty)
        let echoed = messages(.assistSTTResponse).compactMap { AssistTextResponsePayload(content: $0.content) }
        XCTAssertEqual(echoed.map(\.text), ["Turn on the lights"])
    }

    func testRecognizerHearingTheEndOfSpeechStopsTheWatchRecording() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true)

        startStream()
        streamChunk(Data([1, 2]), sequence: 0)
        recognizer.report("Turn on the lights", isFinal: true)
        waitUntil { assistService.assistSource != nil }

        XCTAssertEqual(stoppedStreams, ["stream"])
        XCTAssertEqual(
            assistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "pipeline", expectTTS: true)
        )
        streamChunk(Data([3, 4]), sequence: 1)
        XCTAssertEqual(acks.last?.isListening, false)
    }

    /// Transcribing takes a moment: a recording the user started meanwhile must not be ended by the
    /// previous one's transcript, nor have that transcript answered while it is being made.
    func testTranscriptOfAReplacedRequestIsDropped() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true)
        recognizer.finalTranscript = "Turn on the lights"
        startStream("first")
        streamChunk(Data([1, 2]), sequence: 0, isFinal: true, streamId: "first")

        configuration = AssistConfiguration()
        startStream("second")
        waitUntil { recognizer.didEndAudio }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(
            assistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: true)
        )
        XCTAssertTrue(messages(.assistSTTResponse).isEmpty)
        XCTAssertTrue(messages(.assistError).isEmpty)
        streamChunk(Data([3, 4]), sequence: 0, streamId: "second")
        XCTAssertEqual(acks.last, AssistAudioStreamAckPayload(streamId: "second", isListening: true))
    }

    func testCancelledOnDeviceStreamStopsTheRecognizer() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true)
        startStream()
        streamChunk(Data([1, 2]), sequence: 0)

        cancelStream()

        XCTAssertTrue(recognizer.didCancel)
        XCTAssertFalse(recognizer.didEndAudio)
    }

    func testUnavailableRecognizerReportsTheErrorAndDoesNotListen() {
        configuration = AssistConfiguration(enableOnDeviceSTT: true)
        recognizerFailure = WyomingProtocolError.speechRecognitionNotAuthorized

        startStream()

        let errors = messages(.assistError).compactMap { AssistErrorPayload(content: $0.content) }
        XCTAssertEqual(errors.map(\.code), ["on_device_stt_failed"])
        XCTAssertEqual(acks, [AssistAudioStreamAckPayload(streamId: "stream", isListening: false)])
    }

    // MARK: - Written prompts

    func testPromptRequestsServerTTSByDefault() {
        sendPrompt("Is the door locked?")

        XCTAssertEqual(
            assistService.assistSource,
            .text(input: "Is the door locked?", pipelineId: "pipeline", expectTTS: true)
        )
    }

    func testPromptSkipsServerTTSWhenTTSIsOnDeviceOrMuted() {
        configuration = AssistConfiguration(enableOnDeviceTTS: true)
        sendPrompt("Is the door locked?")
        XCTAssertEqual(
            assistService.assistSource,
            .text(input: "Is the door locked?", pipelineId: "pipeline", expectTTS: false)
        )

        configuration = AssistConfiguration(muteTTS: true)
        sendPrompt("Is the door locked?")
        XCTAssertEqual(
            assistService.assistSource,
            .text(input: "Is the door locked?", pipelineId: "pipeline", expectTTS: false)
        )
    }

    // MARK: - Answers

    func testAnswerIsSpokenOnTheWatchWithTheSelectedVoiceWhenTTSIsOnDevice() {
        configuration = AssistConfiguration(enableOnDeviceTTS: true, onDeviceTTSVoiceIdentifier: "voice")

        service.didReceiveIntentEndContent("The door is locked.")

        let answers = messages(.assistIntentEndResponse).compactMap { AssistTextResponsePayload(content: $0.content) }
        XCTAssertEqual(answers.map(\.text), ["The door is locked."])
        let spoken = messages(.assistOnDeviceTTS).compactMap { AssistOnDeviceTTSPayload(content: $0.content) }
        XCTAssertEqual(spoken, [AssistOnDeviceTTSPayload(text: "The door is locked.", voiceIdentifier: "voice")])
    }

    func testAnswerIsNotSpokenOnTheWatchWhenTheWatchCannotSpeakOnDevice() {
        configuration = AssistConfiguration(enableOnDeviceTTS: true)
        watchSpeaksOnDevice = false

        service.didReceiveIntentEndContent("The door is locked.")

        XCTAssertEqual(messages(.assistIntentEndResponse).count, 1)
        XCTAssertTrue(messages(.assistOnDeviceTTS).isEmpty)
    }

    func testAnswerIsNotSpokenOnTheWatchByDefault() {
        service.didReceiveIntentEndContent("The door is locked.")

        XCTAssertEqual(messages(.assistIntentEndResponse).count, 1)
        XCTAssertTrue(messages(.assistOnDeviceTTS).isEmpty)
    }

    func testAnswerIsNotSpokenOnTheWatchWhenMuted() {
        configuration = AssistConfiguration(muteTTS: true, enableOnDeviceTTS: true)

        service.didReceiveIntentEndContent("The door is locked.")

        XCTAssertEqual(messages(.assistIntentEndResponse).count, 1)
        XCTAssertTrue(messages(.assistOnDeviceTTS).isEmpty)
    }

    func testOnDeviceTTSPayloadRoundTripsAndRejectsMissingText() {
        let payload = AssistOnDeviceTTSPayload(text: "Done", voiceIdentifier: "voice")
        XCTAssertEqual(AssistOnDeviceTTSPayload(content: payload.content), payload)

        let bare = AssistOnDeviceTTSPayload(text: "Done")
        XCTAssertEqual(AssistOnDeviceTTSPayload(content: bare.content), bare)
        XCTAssertNil(bare.content["voiceIdentifier"])

        XCTAssertNil(AssistOnDeviceTTSPayload(content: ["voiceIdentifier": "voice"]))
    }

    // MARK: - Watch the phone cannot push to

    func testReachableWatchGetsResponsesDirectlyAndAnEmptyPong() {
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")
        service.didReceiveIntentEndContent("The door is locked.")

        XCTAssertEqual(messages(.assistSTTResponse).count, 1)
        XCTAssertEqual(messages(.assistIntentEndResponse).count, 1)
        XCTAssertTrue(ping().isEmpty)
    }

    func testTranscriptThePhoneCannotPushGoesBackWithTheNextPong() {
        watchUnreachable = true
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")

        let pong = ping()
        XCTAssertTrue(sentMessages.isEmpty)
        XCTAssertEqual(pong.map(\.identifier), [InteractiveImmediateResponses.assistSTTResponse.rawValue])
        let transcripts = pong.compactMap { AssistTextResponsePayload(content: $0.content)?.text }
        XCTAssertEqual(transcripts, ["Is the door locked?"])
        XCTAssertTrue(ping().isEmpty)
    }

    func testResponseTheConnectivityLayerRefusesGoesBackWithTheNextPong() {
        service.send = WatchCommunicatorService().send
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")

        XCTAssertEqual(ping().map(\.identifier), [InteractiveImmediateResponses.assistSTTResponse.rawValue])
    }

    func testPingFromTheWatchIsAnsweredWithTheResponsesThePhoneCouldNotPush() {
        watchUnreachable = true
        service.setupMessages()
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")
        flushMainQueue()

        var pongs: [HAWatchConnectivity.ImmediateMessage] = []
        let answered = expectation(description: "pong")
        answered.assertForOverFulfill = false
        Communicator.shared.interactiveImmediateMessage.notify(.init(
            identifier: InteractiveImmediateMessages.ping.rawValue,
            reply: { pongs.append($0); answered.fulfill() }
        ))
        wait(for: [answered], timeout: 1)

        XCTAssertEqual(
            pongs.flatMap { PongPayload(content: $0.content).assistMessages.map(\.identifier) },
            [InteractiveImmediateResponses.assistSTTResponse.rawValue]
        )
    }

    func testPongHoldsTheAnswerUntilTheRunEndsSoTheSpeechAfterItIsNotLost() {
        watchUnreachable = true
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")
        service.didReceiveIntentEndContent("The door is locked.")

        XCTAssertEqual(ping().map(\.identifier), [InteractiveImmediateResponses.assistSTTResponse.rawValue])

        service.didReceiveTtsMediaUrl(URL(string: "https://example.com/api/tts_proxy/answer.mp3")!)
        service.didReceiveEvent(.runEnd)

        XCTAssertEqual(ping().map(\.identifier), [
            InteractiveImmediateResponses.assistIntentEndResponse.rawValue,
            InteractiveImmediateResponses.assistTTSResponse.rawValue,
        ])
    }

    func testAnErrorEndsTheRunAndReleasesTheHeldAnswer() {
        watchUnreachable = true
        sendRecording()
        service.didReceiveIntentEndContent("The door is locked.")
        service.didReceiveError(code: "tts-failed", message: "Speech failed")

        XCTAssertEqual(ping().map(\.identifier), [
            InteractiveImmediateResponses.assistIntentEndResponse.rawValue,
            InteractiveImmediateResponses.assistError.rawValue,
        ])
    }

    func testResponsesQueueBehindAnUndeliveredOneToKeepTheirOrder() {
        watchUnreachable = true
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")
        flushMainQueue()

        watchUnreachable = false
        service.didReceiveIntentEndContent("The door is locked.")
        service.didReceiveEvent(.runEnd)

        XCTAssertTrue(sentMessages.isEmpty)
        XCTAssertEqual(ping().map(\.identifier), [
            InteractiveImmediateResponses.assistSTTResponse.rawValue,
            InteractiveImmediateResponses.assistIntentEndResponse.rawValue,
        ])
    }

    func testResponsesGoStraightToTheWatchAgainOnceThePongClearedTheBacklog() {
        watchUnreachable = true
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")
        XCTAssertEqual(ping().count, 1)

        watchUnreachable = false
        service.didReceiveIntentEndContent("The door is locked.")

        XCTAssertEqual(messages(.assistIntentEndResponse).count, 1)
        XCTAssertTrue(ping().isEmpty)
    }

    func testANewRunDropsResponsesLeftOverFromThePreviousOne() {
        watchUnreachable = true
        sendRecording()
        service.didReceiveIntentEndContent("The door is locked.")
        service.didReceiveEvent(.runEnd)
        flushMainQueue()

        sendPrompt("Is the window open?")

        XCTAssertTrue(ping().isEmpty)
    }

    func testLateFailuresGoBackWithThePongInTheOrderTheResponsesWereMade() {
        failsLater = true
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")
        service.didReceiveIntentEndContent("The door is locked.")
        service.didReceiveEvent(.runEnd)

        lateFailures.reversed().forEach { $0() }

        XCTAssertEqual(ping().map(\.identifier), [
            InteractiveImmediateResponses.assistSTTResponse.rawValue,
            InteractiveImmediateResponses.assistIntentEndResponse.rawValue,
        ])
    }

    func testLateFailureOfAPreviousRunIsNotHandedToTheNextOne() {
        failsLater = true
        sendRecording()
        service.didReceiveIntentEndContent("The door is locked.")
        service.didReceiveEvent(.runEnd)

        sendPrompt("Is the window open?")
        lateFailures.forEach { $0() }

        XCTAssertTrue(ping().isEmpty)
    }

    func testResponsesAreNotKeptForAWatchThatCannotReadThemFromThePong() {
        service.watchReadsAssistResponsesFromPong = WatchCommunicatorService().watchReadsAssistResponsesFromPong
        watchUnreachable = true
        sendRecording()
        service.didReceiveSttContent("Is the door locked?")

        XCTAssertTrue(ping().isEmpty)
    }

    func testPongPayloadRoundTripsItsMessagesAndSkipsMalformedOnes() {
        let payload = PongPayload(assistMessages: [
            (identifier: InteractiveImmediateResponses.assistIntentEndResponse.rawValue, content: ["content": "Done"]),
        ])
        XCTAssertTrue(PropertyListSerialization.propertyList(payload.content, isValidFor: .binary))

        let decoded = PongPayload(content: payload.content).assistMessages
        XCTAssertEqual(decoded.map(\.identifier), [InteractiveImmediateResponses.assistIntentEndResponse.rawValue])
        XCTAssertEqual(decoded.first?.content["content"] as? String, "Done")

        XCTAssertTrue(PongPayload().content.isEmpty)
        XCTAssertTrue(PongPayload(content: [:]).assistMessages.isEmpty)
        XCTAssertTrue(PongPayload(content: ["assistMessages": [
            ["identifier": "assistIntentEndResponse"],
            ["content": ["content": "Done"]],
        ]]).assistMessages.isEmpty)
    }
}

@MainActor
private final class FakeSpeechRecognizer: OnDeviceSpeechRecognizing {
    struct TestError: LocalizedError {
        var errorDescription: String? {
            "The recognizer is asleep"
        }
    }

    var finalTranscript = ""
    var failure: Error?
    private(set) var didReceiveAudio = false
    private(set) var didEndAudio = false
    private(set) var didCancel = false

    private var onTranscript: ((String, Bool) -> Void)?
    private var onFailure: ((Error) -> Void)?

    func start(
        onTranscript: @escaping (String, Bool) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.onTranscript = onTranscript
        self.onFailure = onFailure
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        didReceiveAudio = true
    }

    func endAudio() {
        didEndAudio = true
        if let failure {
            onFailure?(failure)
        } else {
            onTranscript?(finalTranscript, true)
        }
    }

    func cancel() {
        didCancel = true
    }

    /// What the recognizer heard while the audio is still streaming in.
    func report(_ transcript: String, isFinal: Bool) {
        onTranscript?(transcript, isFinal)
    }
}
