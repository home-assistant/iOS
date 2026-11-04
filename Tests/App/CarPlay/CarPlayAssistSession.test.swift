import AVFoundation
import CarPlay
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import XCTest

@available(iOS 26.4, *)
final class CarPlayAssistSessionTests: XCTestCase {
    /// The production download goes through the certificate-aware session and reports the transport
    /// error to its caller; a closed loopback port fails at once without leaving the machine.
    func testTheDefaultDownloadReportsAConnectionFailure() throws {
        let download = CarPlayAssistSession.certificateAwareDownload(server: Server.fake())
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:9/tts.mp3"))
        let finished = expectation(description: "download finished")
        var reportedError: Error?
        var reportedData: Data?
        download(url) { data, error in
            reportedData = data
            reportedError = error
            finished.fulfill()
        }
        wait(for: [finished], timeout: 30)
        XCTAssertNil(reportedData)
        XCTAssertNotNil(reportedError)
    }

    private var mockAudioRecorder: MockAudioRecorder!
    private var mockAssistService: MockAssistService!
    private var mockTonePlayer: MockCarPlayAssistTonePlayer!
    private var sut: CarPlayAssistSession?
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    /// Held strongly: the session's `interfaceController` is weak.
    private var navigator: FakeCarPlayNavigator?
    private var privateSettings: PrivateSettingsStore?
    private var ttsDownloader: StubTTSDownloader!

    override func setUp() {
        super.setUp()
        mockAudioRecorder = MockAudioRecorder()
        previousCachedApis = Current.cachedApis
        mockAssistService = MockAssistService()
        mockTonePlayer = MockCarPlayAssistTonePlayer()
        ttsDownloader = StubTTSDownloader()
    }

    override func tearDown() {
        sut?.stop()
        sut = nil
        navigator = nil
        privateSettings?.restore()
        privateSettings = nil
        ttsDownloader = nil
        // The code under test caches an API for its server. XCTest keeps this test case alive for the
        // whole run, and an API left in the cache stays registered with the app's sensor container,
        // which every later sensor signal fans out to.
        Current.cachedApis = previousCachedApis
        previousCachedApis = nil
        super.tearDown()
    }

    private func makeSut(
        pipelineId: String = "pipeline",
        prompt: String? = nil,
        configuration: AssistConfiguration = AssistConfiguration(),
        speechTranscriber: (any SpeechTranscriberProtocol)? = nil,
        speechSynthesizer: (any SpeechSynthesizerProtocol)? = nil,
        serverTTSPlayback: ((URL) -> Void)? = nil,
        responseTimeout: TimeInterval = 30,
        intentStageTimeout: TimeInterval = 300
    ) -> CarPlayAssistSession {
        let session = CarPlayAssistSession(
            interfaceController: navigator,
            server: ServerFixture.standard,
            pipelineId: pipelineId,
            prompt: prompt,
            audioRecorder: mockAudioRecorder,
            assistService: mockAssistService,
            assistConfiguration: configuration,
            speechTranscriber: speechTranscriber,
            speechSynthesizer: speechSynthesizer,
            serverTTSPlayback: serverTTSPlayback,
            ttsAudioDownload: ttsDownloader.download,
            tonePlayer: mockTonePlayer,
            responseTimeout: responseTimeout,
            intentStageTimeout: intentStageTimeout
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

    func testRecordingFailureCancelsRunAndStopsSendingAudio() {
        let sut = makeSut()
        sut.start()
        sut.didReceiveGreenLightForAudioInput()
        let error = AudioRecorderError.captureDeviceUnavailable

        sut.didFailToRecord(error: error)
        sut.didOutputSample(data: Data([0x01]))

        XCTAssertTrue(mockAssistService.cancelRunCalled)
        XCTAssertFalse(mockAssistService.sendAudioDataCalled)
        XCTAssertEqual(sut.currentState, .error(error.localizedDescription))
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

    /// A run the server refuses fails before speech-to-text ever ends, so the error state is the
    /// only thing left to release the microphone the session opened when it started.
    func testErrorWhileRecordingStopsRecorder() {
        let sut = makeSut()
        sut.start()
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)

        sut.didReceiveError(code: "stt-provider-missing", message: "No speech-to-text provider")

        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
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

    // MARK: - Response watchdog

    /// A conversation agent that does not stream sends nothing between `intent-start` and
    /// `intent-end`, so the silence deadline must not cut it off while the server still runs it.
    func testSilentIntentStageIsNotCutOffBySilenceTimeout() {
        let sut = makeSut(prompt: "Turn on the lights", responseTimeout: 0.05)
        sut.start()
        sut.didReceiveEvent(.runStart)
        sut.didReceiveEvent(.intentStart)

        // Lets the main queue run well past the silence deadline.
        let silence = expectation(description: "silence")
        silence.isInverted = true
        wait(for: [silence], timeout: 0.5)

        XCTAssertEqual(sut.currentState, .processing)
        XCTAssertFalse(mockAssistService.cancelRunCalled)
        sut.didReceiveEvent(.intentEnd)
        sut.didReceiveIntentEndContent("The lights are on")
        XCTAssertEqual(sut.currentState, .responding)
    }

    /// When the run goes quiet past its deadline the session abandons it, and a response that
    /// still arrives afterwards is neither shown nor played.
    func testWatchdogCancelsRunAndIgnoresLateResponse() {
        let synthesizer = MockSpeechSynthesizer()
        var playedTTSURLs: [URL] = []
        let sut = makeSut(
            prompt: "Turn on the lights",
            configuration: AssistConfiguration(enableOnDeviceTTS: true),
            speechSynthesizer: synthesizer,
            serverTTSPlayback: { playedTTSURLs.append($0) },
            responseTimeout: 0.05
        )
        sut.start()

        let errorShown = expectation(for: NSPredicate { _, _ in sut.currentState.isError }, evaluatedWith: nil)
        wait(for: [errorShown], timeout: 30)
        XCTAssertTrue(mockAssistService.cancelRunCalled)

        sut.didReceiveIntentEndContent("The lights are on")
        sut.didReceiveTtsMediaUrl(URL(string: "https://example.com/tts.mp3")!)

        XCTAssertTrue(sut.currentState.isError)
        XCTAssertFalse(synthesizer.speakCalled)
        XCTAssertEqual(playedTTSURLs, [])
    }

    /// The counterpart of the late response test: in a run that is still going, the server's
    /// TTS URL is played.
    func testTtsMediaUrlIsPlayedDuringRun() {
        var playedTTSURLs: [URL] = []
        let sut = makeSut(prompt: "Turn on the lights", serverTTSPlayback: { playedTTSURLs.append($0) })
        sut.start()
        sut.didReceiveIntentEndContent("The lights are on")

        let url = URL(string: "https://example.com/tts.mp3")!
        sut.didReceiveTtsMediaUrl(url)

        XCTAssertEqual(playedTTSURLs, [url])
        XCTAssertEqual(sut.currentState, .responding)
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

    // MARK: - Lifecycle, audio session events and TTS playback without sound

    /// Gives the test its own settings store, then applies `mutate` to the CarPlay Assist debug
    /// settings the session reads.
    private func useDebugSettings(_ mutate: (inout CarPlayAssistDebugSettings) -> Void) {
        if privateSettings == nil {
            privateSettings = PrivateSettingsStore()
        }
        var settings = Current.settingsStore.carPlayAssistDebugSettings
        mutate(&settings)
        Current.settingsStore.carPlayAssistDebugSettings = settings
    }

    private let ttsURL = URL(string: "https://example.com/tts.mp3")!

    private var missingFile: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("carplay-tts-missing-\(UUID().uuidString).mp3")
    }

    private func silentPlayer() throws -> AVAudioPlayer {
        try AVAudioPlayer(data: CarPlayAssistTonePlayer.makeWAVData(segments: [.init(frequency: 0, duration: 0.01)]))
    }

    /// Spins the main run loop until `condition` holds, failing (not hanging) after 10 seconds.
    private func spinUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "condition not met within 10 s", file: file, line: line)
    }

    private func postInterruption(_ userInfo: [AnyHashable: Any]?) {
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )
    }

    func testStateFlags() {
        XCTAssertFalse(CarPlayAssistSession.State.idle.isRecording)
        XCTAssertTrue(CarPlayAssistSession.State.recording.isRecording)
        XCTAssertTrue(CarPlayAssistSession.State.error("x").isError)
        XCTAssertFalse(CarPlayAssistSession.State.responding.isError)
        XCTAssertTrue(CarPlayAssistSession.State.processing.isAwaitingPipelineResponse)
        XCTAssertFalse(CarPlayAssistSession.State.idle.isAwaitingPipelineResponse)
    }

    /// Leaving the voice screen (CarPlay popped it) ends the session without dismissing again.
    func testTheVoiceScreenDisappearingEndsTheSession() throws {
        navigator = FakeCarPlayNavigator()
        let sut = makeSut()
        var stops = 0
        sut.onStop = { stops += 1 }
        sut.start()
        let voiceTemplate = try XCTUnwrap(navigator?.presentedTemplates.first as? CPVoiceControlTemplate)

        sut.templateWillDisappear(template: CPListTemplate(title: "Other", sections: []))
        XCTAssertEqual(stops, 0)

        sut.templateWillDisappear(template: voiceTemplate)
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(navigator?.dismissCount, 0)
        sut.stop()
        XCTAssertEqual(stops, 1, "stopping twice reports once")
    }

    func testStoppingDismissesTheVoiceScreenEvenWhenCarPlayReportsAnError() {
        navigator = FakeCarPlayNavigator()
        navigator?.dismissError = NSError(domain: "test", code: 1)
        let sut = makeSut()
        var stops = 0
        sut.onStop = { stops += 1 }
        sut.start()

        sut.stop()

        XCTAssertEqual(navigator?.dismissCount, 1)
        XCTAssertEqual(stops, 1)
    }

    /// The help button ends the session, then shows how to change the playback strategy.
    func testPlaybackHelpReplacesTheSessionWithTheHelpScreen() {
        navigator = FakeCarPlayNavigator()
        navigator?.pushError = NSError(domain: "test", code: 1)
        let sut = makeSut()
        sut.start()

        sut.showPlaybackHelp()

        XCTAssertEqual(navigator?.dismissCount, 1)
        XCTAssertTrue(navigator?.pushedTemplates.last is CPInformationTemplate)
    }

    func testRestartingListensAgainOrResendsThePrompt() {
        let voice = makeSut()
        voice.start()
        voice.didReceiveError(code: "x", message: "failed")
        voice.restartPrompt()
        XCTAssertEqual(voice.currentState, .recording)
        voice.stop()

        let prompt = makeSut(prompt: "Turn on the lights")
        prompt.start()
        mockAssistService.assistSource = nil
        prompt.restartPrompt()
        XCTAssertEqual(
            mockAssistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "pipeline", expectTTS: true)
        )
        prompt.restartRecording()
        XCTAssertEqual(prompt.currentState, .recording)
    }

    /// A phone call (or anything else taking the audio session) ends the session; an interruption
    /// ending, or one without a type, changes nothing.
    func testAnAudioInterruptionEndsTheSession() {
        navigator = FakeCarPlayNavigator()
        let sut = makeSut()
        var stops = 0
        sut.onStop = { stops += 1 }
        sut.start()

        postInterruption(nil)
        postInterruption([AVAudioSessionInterruptionTypeKey: UInt(99)])
        postInterruption([
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
        ])
        postInterruption([AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        XCTAssertEqual(stops, 0)

        postInterruption([AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        XCTAssertEqual(stops, 1)
        postInterruption([AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        XCTAssertEqual(stops, 1)
    }

    func testAMediaServicesResetReconfiguresOnlyARunningSession() {
        useDebugSettings { settings in
            settings.duckOthers = true
            settings.interruptSpokenAudio = true
        }
        let sut = makeSut()
        sut.start()

        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )
        XCTAssertEqual(sut.currentState, .recording)

        sut.stop()
        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    func testRecorderAndTextCallbacksThatCarPlayIgnores() {
        let sut = makeSut()
        sut.start()

        sut.didStopRecording()
        sut.didReceiveSttContent("hello")
        sut.didReceiveStreamResponseChunk("partial")

        XCTAssertEqual(sut.currentState, .recording)
    }

    /// A downloaded clip that finishes idles the session, or listens again in a continued
    /// conversation; one that can't be decoded is an error.
    func testADownloadedClipFinishingIdlesOrListensAgain() throws {
        let player = try silentPlayer()
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()
        sut.didReceiveIntentEndContent("Done")

        sut.audioPlayerDidFinishPlaying(player, successfully: true)
        XCTAssertEqual(sut.currentState, .idle)

        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = true
        sut.audioPlayerDidFinishPlaying(player, successfully: true)
        XCTAssertTrue(mockAssistService.resetShouldStartListeningAgainAfterPlaybackEndCalled)
        XCTAssertEqual(sut.currentState, .recording)

        sut.audioPlayerDecodeErrorDidOccur(player, error: nil)
        XCTAssertTrue(sut.currentState.isError)

        sut.stop()
        sut.audioPlayerDidFinishPlaying(player, successfully: true)
        XCTAssertTrue(sut.currentState.isError)
    }

    @MainActor
    func testOnDeviceTranscriptionThatCannotStartIsAnError() async {
        let transcriber = MockSpeechTranscriber()
        transcriber.startListeningError = NSError(domain: "test", code: 1)
        let sut = makeSut(configuration: AssistConfiguration(enableOnDeviceSTT: true), speechTranscriber: transcriber)
        sut.start()

        await waitUntil(timeout: 10) { sut.currentState.isError }
        XCTAssertTrue(sut.currentState.isError)
    }

    @MainActor
    func testAnEmptyFinalTranscriptIsNoSpeech() async {
        let transcriber = MockSpeechTranscriber()
        let sut = makeSut(configuration: AssistConfiguration(enableOnDeviceSTT: true), speechTranscriber: transcriber)
        sut.start()
        await waitUntil(timeout: 10) { transcriber.startListeningCalled }

        transcriber.simulateTranscriptUpdate("   ", isFinal: true)

        XCTAssertEqual(sut.currentState, .error("No speech was recognized"))
    }

    /// Pipeline events arrive on HAKit's queue; the voice screen still updates on the main thread.
    func testEventsFromABackgroundThreadUpdateTheVoiceScreen() {
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()
        let delivered = expectation(description: "event delivered")

        DispatchQueue.global().async {
            sut.didReceiveIntentEndContent("Done")
            delivered.fulfill()
        }

        wait(for: [delivered], timeout: 10)
        spinUntil { sut.currentState == .responding }
    }

    // A clip that can't be loaded never makes a sound: each path below ends in the error state.

    func testAClipThatCannotBeDownloadedIsAnError() {
        useDebugSettings { settings in
            settings.ttsPlaybackStrategy = .downloadedAVAudioPlayer
            settings.ttsReconfigureAudioSession = true
            settings.ttsDeactivateBeforeReconfigure = true
            settings.ttsActivateAudioSession = true
            settings.ttsDuckOthers = true
            settings.ttsInterruptSpokenAudio = true
        }
        let failure = URLError(.cannotConnectToHost)
        ttsDownloader.error = failure
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()
        sut.didReceiveIntentEndContent("Done")

        sut.didReceiveTtsMediaUrl(ttsURL)

        spinUntil { sut.currentState.isError }
        XCTAssertEqual(ttsDownloader.requestedURLs, [ttsURL])
        XCTAssertEqual(sut.currentState, .error(failure.localizedDescription))
    }

    func testAnEmptyClipIsAnError() {
        useDebugSettings { $0.ttsPlaybackStrategy = .downloadedAVAudioPlayer }
        ttsDownloader.data = Data()
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()
        sut.didReceiveIntentEndContent("Done")

        sut.didReceiveTtsMediaUrl(ttsURL)

        spinUntil { sut.currentState.isError }
        XCTAssertEqual(ttsDownloader.requestedURLs, [ttsURL])
        XCTAssertEqual(sut.currentState, .error("Downloaded empty TTS audio data"))
    }

    /// The download succeeds, so the error can only come from decoding the bytes.
    func testAClipThatIsNotAudioIsAnError() {
        useDebugSettings { $0.ttsPlaybackStrategy = .downloadedAVAudioPlayer }
        ttsDownloader.data = Data("not audio at all".utf8)
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()
        sut.didReceiveIntentEndContent("Done")

        sut.didReceiveTtsMediaUrl(ttsURL)

        spinUntil { sut.currentState.isError }
        XCTAssertEqual(ttsDownloader.requestedURLs, [ttsURL])
        XCTAssertNotEqual(sut.currentState, .error("Downloaded empty TTS audio data"))
        XCTAssertNotEqual(sut.currentState, .error("AVAudioPlayer failed to start TTS playback"))
    }

    /// A streamed clip that can't be loaded fails, after the configured delay. Whether the session
    /// then falls back to downloading it depends on whether AVPlayer briefly reported playing, so
    /// the test settles on either outcome.
    func testAStreamedClipThatFailsEndsPlayback() {
        useDebugSettings { settings in
            settings.ttsPlaybackStrategy = .avPlayer
            settings.ttsPlaybackDelay = .ms100
            settings.avPlayerAutomaticallyWaitsToMinimizeStalling = false
        }
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()
        sut.didReceiveIntentEndContent("Done")

        sut.didReceiveTtsMediaUrl(missingFile)

        spinUntil { sut.currentState.isError || sut.ttsPlayer.currentItem?.status == .failed }
    }

    /// The streamed player's item notifications end playback: finished, stalled, failed.
    func testStreamedPlaybackNotificationsEndThePlayback() throws {
        useDebugSettings { $0.ttsPlaybackStrategy = .avPlayer }
        let sut = makeSut(prompt: "Turn on the lights")
        sut.start()
        sut.didReceiveIntentEndContent("Done")
        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = true

        sut.didReceiveTtsMediaUrl(missingFile)
        let item = try XCTUnwrap(sut.ttsPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
        XCTAssertTrue(mockAssistService.resetShouldStartListeningAgainAfterPlaybackEndCalled)

        NotificationCenter.default.post(name: .AVPlayerItemPlaybackStalled, object: item)
        NotificationCenter.default.post(
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            userInfo: [AVPlayerItemFailedToPlayToEndTimeErrorKey: NSError(domain: "test", code: 1)]
        )
        NotificationCenter.default.post(name: .AVPlayerItemFailedToPlayToEndTime, object: item)
        XCTAssertTrue(sut.currentState.isError)
        XCTAssertTrue(mockTonePlayer.playedTones.contains(.error))

        sut.stop()
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
    }
}

/// Answers the session's TTS download with fixed bytes or an error, from a background queue as
/// URLSession does, so no test reaches the network or depends on how URLSession treats a URL.
private final class StubTTSDownloader {
    var data: Data?
    var error: Error?
    private(set) var requestedURLs: [URL] = []

    func download(_ url: URL, completion: @escaping (Data?, Error?) -> Void) {
        requestedURLs.append(url)
        let data = data
        let error = error ?? (data == nil ? URLError(.resourceUnavailable) : nil)
        DispatchQueue.global().async {
            completion(data, error)
        }
    }
}
