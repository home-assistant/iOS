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
    private var watchUnreachable = false
    private var sentMessages: [HAWatchConnectivity.ImmediateMessage] = []
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
        watchUnreachable = false
        sentMessages = []

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
            if watchUnreachable {
                failed(HAWatchConnectivity.ConnectivityError.notReachable)
            } else {
                sentMessages.append(message)
            }
        }
        service.watchSpeaksOnDevice = { [weak self] in self?.watchSpeaksOnDevice ?? true }
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

    func cancel() {}
}
