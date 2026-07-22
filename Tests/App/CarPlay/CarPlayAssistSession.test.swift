import CarPlay
@testable import HomeAssistant
@testable import Shared
import XCTest

@available(iOS 26.4, *)
final class CarPlayAssistSessionTests: XCTestCase {
    private var mockAudioRecorder: MockAudioRecorder!
    private var mockAssistService: MockAssistService!
    private var mockTonePlayer: MockCarPlayAssistTonePlayer!
    private var sut: CarPlayAssistSession?

    override func setUp() {
        super.setUp()
        mockAudioRecorder = MockAudioRecorder()
        mockAssistService = MockAssistService()
        mockTonePlayer = MockCarPlayAssistTonePlayer()
    }

    override func tearDown() {
        sut?.stop()
        sut = nil
        super.tearDown()
    }

    private func makeSut(
        pipelineId: String = "pipeline",
        prompt: String? = nil,
        configuration: AssistConfiguration = AssistConfiguration(),
        speechTranscriber: (any SpeechTranscriberProtocol)? = nil,
        speechSynthesizer: (any SpeechSynthesizerProtocol)? = nil
    ) -> CarPlayAssistSession {
        let session = CarPlayAssistSession(
            interfaceController: nil,
            server: ServerFixture.standard,
            pipelineId: pipelineId,
            prompt: prompt,
            audioRecorder: mockAudioRecorder,
            assistService: mockAssistService,
            assistConfiguration: configuration,
            speechTranscriber: speechTranscriber,
            speechSynthesizer: speechSynthesizer,
            tonePlayer: mockTonePlayer
        )
        sut = session
        return session
    }

    /// Yields the main actor until `condition` is true or `timeout` elapses, so work the
    /// session schedules via `Task { @MainActor in ... }` gets a chance to run.
    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
    }

    // MARK: - Voice flow (server STT)

    func testStartVoiceFlowStartsRecording() {
        let sut = makeSut()
        sut.start()

        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
        XCTAssertEqual(sut.currentState, .recording)
    }

    func testDidStartRecordingRequestsAudioPipelineWithServerTTS() {
        let sut = makeSut()
        sut.start()
        sut.didStartRecording(with: 16000)

        XCTAssertEqual(
            mockAssistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: true)
        )
        XCTAssertTrue(mockTonePlayer.playedTones.contains(.startRecording))
    }

    func testDidStartRecordingSkipsServerTTSWhenOnDeviceTTSEnabled() {
        let sut = makeSut(configuration: AssistConfiguration(enableOnDeviceTTS: true))
        sut.start()
        sut.didStartRecording(with: 16000)

        XCTAssertEqual(
            mockAssistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: false)
        )
    }

    func testAudioSamplesForwardedOnlyAfterGreenLight() {
        let sut = makeSut()
        sut.start()

        sut.didOutputSample(data: Data([0x01]))
        XCTAssertFalse(mockAssistService.sendAudioDataCalled)

        sut.didReceiveGreenLightForAudioInput()
        sut.didOutputSample(data: Data([0x02]))
        XCTAssertTrue(mockAssistService.sendAudioDataCalled)
        XCTAssertEqual(mockAssistService.audioDataSent, Data([0x02]))
    }

    func testSttEndStopsRecordingAndTransitionsToProcessing() {
        let sut = makeSut()
        sut.start()
        sut.didReceiveEvent(.sttEnd)

        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
        XCTAssertTrue(mockAssistService.finishSendingAudioCalled)
        XCTAssertTrue(mockTonePlayer.playedTones.contains(.processing))
        XCTAssertEqual(sut.currentState, .processing)
    }

    func testIntentEndTransitionsToResponding() {
        let sut = makeSut()
        sut.start()
        sut.didReceiveEvent(.sttEnd)
        sut.didReceiveIntentEndContent("The lights are on")

        XCTAssertEqual(sut.currentState, .responding)
    }

    func testErrorEntersErrorStateAndPlaysErrorTone() {
        let sut = makeSut()
        sut.start()
        sut.didReceiveError(code: "code", message: "boom")

        XCTAssertEqual(sut.currentState, .error("boom"))
        XCTAssertTrue(mockTonePlayer.playedTones.contains(.error))
    }

    func testEventsAreIgnoredAfterStop() {
        let sut = makeSut()
        sut.start()
        sut.stop()

        sut.didReceiveIntentEndContent("late response")
        XCTAssertNotEqual(sut.currentState, .responding)

        sut.didReceiveError(code: "code", message: "late error")
        XCTAssertFalse(sut.currentState.isError)
    }

    func testStopStopsRecorderAndTones() {
        let sut = makeSut()
        sut.start()
        sut.stop()

        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
        XCTAssertTrue(mockAssistService.finishSendingAudioCalled)
        XCTAssertTrue(mockTonePlayer.stopCalled)
    }

    // MARK: - Prompt flow

    func testStartWithPromptSendsTextPipelineWithoutRecording() {
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()

        XCTAssertEqual(
            mockAssistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "pipeline", expectTTS: true)
        )
        XCTAssertFalse(mockAudioRecorder.startRecordingCalled)
        XCTAssertEqual(sut.currentState, .processing)
    }

    func testStartWithPromptSkipsServerTTSWhenOnDeviceTTSEnabled() {
        let sut = makeSut(
            prompt: "Turn on the lights",
            configuration: AssistConfiguration(enableOnDeviceTTS: true)
        )
        sut.start()

        XCTAssertEqual(
            mockAssistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "pipeline", expectTTS: false)
        )
    }

    // MARK: - On-device STT

    @MainActor
    func testOnDeviceSTTUsesTranscriberInsteadOfRecorder() async {
        let transcriber = MockSpeechTranscriber()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceSTT: true),
            speechTranscriber: transcriber
        )
        sut.start()

        await waitUntil { transcriber.startListeningCalled }
        XCTAssertTrue(transcriber.startListeningCalled)
        XCTAssertFalse(transcriber.managesAudioSession)
        XCTAssertFalse(mockAudioRecorder.startRecordingCalled)
        XCTAssertEqual(sut.currentState, .recording)
    }

    @MainActor
    func testOnDeviceFinalTranscriptIsSentThroughTextPipeline() async {
        let transcriber = MockSpeechTranscriber()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceSTT: true),
            speechTranscriber: transcriber
        )
        sut.start()
        await waitUntil { transcriber.startListeningCalled }

        transcriber.simulateTranscriptUpdate("How many lights are on?", isFinal: true)

        XCTAssertEqual(
            mockAssistService.assistSource,
            .text(input: "How many lights are on?", pipelineId: "pipeline", expectTTS: true)
        )
        XCTAssertTrue(mockTonePlayer.playedTones.contains(.processing))
        XCTAssertEqual(sut.currentState, .processing)
    }

    @MainActor
    func testOnDevicePartialTranscriptIsIgnored() async {
        let transcriber = MockSpeechTranscriber()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceSTT: true),
            speechTranscriber: transcriber
        )
        sut.start()
        await waitUntil { transcriber.startListeningCalled }

        transcriber.simulateTranscriptUpdate("How many", isFinal: false)

        XCTAssertNil(mockAssistService.assistSource)
        XCTAssertEqual(sut.currentState, .recording)
    }

    @MainActor
    func testOnDeviceListeningStoppingWithoutTranscriptEntersErrorState() async {
        let transcriber = MockSpeechTranscriber()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceSTT: true),
            speechTranscriber: transcriber
        )
        sut.start()
        // The listening-active flag is set right before the recording indicator tone.
        await waitUntil { [mockTonePlayer] in
            mockTonePlayer?.playedTones.contains(.startRecording) == true
        }

        transcriber.simulateListeningStateChange(false)

        XCTAssertTrue(sut.currentState.isError)
        XCTAssertTrue(mockTonePlayer.playedTones.contains(.error))
    }

    @MainActor
    func testOnDeviceTranscriptionErrorEntersErrorState() async {
        let transcriber = MockSpeechTranscriber()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceSTT: true),
            speechTranscriber: transcriber
        )
        sut.start()
        await waitUntil { transcriber.startListeningCalled }

        transcriber.simulateError(SpeechTranscriber.TranscriberError.notAvailable)

        XCTAssertTrue(sut.currentState.isError)
    }

    // MARK: - On-device TTS

    func testIntentEndSpeaksOnDeviceWhenEnabled() {
        let synthesizer = MockSpeechSynthesizer()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceTTS: true),
            speechSynthesizer: synthesizer
        )
        sut.start()
        sut.didReceiveEvent(.sttEnd)
        sut.didReceiveIntentEndContent("The lights are on")

        XCTAssertEqual(synthesizer.lastSpokenText, "The lights are on")
        XCTAssertFalse(synthesizer.managesAudioSession)
        XCTAssertEqual(sut.currentState, .responding)
    }

    func testIntentEndDoesNotSpeakOnDeviceWhenDisabled() {
        let synthesizer = MockSpeechSynthesizer()
        let sut = makeSut(speechSynthesizer: synthesizer)
        sut.start()
        sut.didReceiveIntentEndContent("The lights are on")

        XCTAssertFalse(synthesizer.speakCalled)
    }

    func testOnDeviceSpeechFinishedGoesIdle() {
        let synthesizer = MockSpeechSynthesizer()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceTTS: true),
            speechSynthesizer: synthesizer
        )
        sut.start()
        sut.didReceiveIntentEndContent("Done")
        synthesizer.simulateFinished()

        XCTAssertEqual(sut.currentState, .idle)
    }

    func testOnDeviceSpeechFinishedRestartsRecordingForContinueConversation() {
        let synthesizer = MockSpeechSynthesizer()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceTTS: true),
            speechSynthesizer: synthesizer
        )
        sut.start()
        sut.didReceiveIntentEndContent("Which room?")

        mockAudioRecorder.startRecordingCalled = false
        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = true
        synthesizer.simulateFinished()

        XCTAssertTrue(mockAssistService.resetShouldStartListeningAgainAfterPlaybackEndCalled)
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
        XCTAssertEqual(sut.currentState, .recording)
    }

    // MARK: - Muted TTS (does not apply to CarPlay)

    func testMuteTTSDoesNotSuppressServerTTSRequest() {
        let sut = makeSut(configuration: AssistConfiguration(muteTTS: true))
        sut.start()
        sut.didStartRecording(with: 16000)

        XCTAssertEqual(
            mockAssistService.assistSource,
            .audio(pipelineId: "pipeline", audioSampleRate: 16000, tts: true)
        )
    }

    func testMuteTTSDoesNotSuppressOnDeviceSpeech() {
        let synthesizer = MockSpeechSynthesizer()
        let sut = makeSut(
            configuration: AssistConfiguration(muteTTS: true, enableOnDeviceTTS: true),
            speechSynthesizer: synthesizer
        )
        sut.start()
        sut.didReceiveEvent(.sttEnd)
        sut.didReceiveIntentEndContent("The lights are on")

        XCTAssertEqual(synthesizer.lastSpokenText, "The lights are on")
        XCTAssertEqual(sut.currentState, .responding)
    }

    func testEmptyIntentContentWithOnDeviceTTSGoesIdleWithoutSpeaking() {
        let synthesizer = MockSpeechSynthesizer()
        let sut = makeSut(
            configuration: AssistConfiguration(enableOnDeviceTTS: true),
            speechSynthesizer: synthesizer
        )
        sut.start()
        sut.didReceiveIntentEndContent("   ")

        XCTAssertFalse(synthesizer.speakCalled)
        XCTAssertEqual(sut.currentState, .idle)
    }
}
