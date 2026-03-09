@testable import HomeAssistant
@testable import Shared
import XCTest

final class AssistViewModelTests: XCTestCase {
    private var sut: AssistViewModel!
    private var mockAudioRecorder: MockAudioRecorder!
    private var mockAudioPlayer: MockAudioPlayer!
    private var mockAssistService: MockAssistService!

    override func setUp() async throws {
        mockAudioRecorder = MockAudioRecorder()
        mockAudioPlayer = MockAudioPlayer()
        mockAssistService = MockAssistService()

        sut = makeSut()
        AssistSession.shared.delegate = nil
        AssistSession.shared.inProgress = false
    }

    private func makeSut(
        autoStartRecording: Bool = false,
        speechTranscriber: (any SpeechTranscriberProtocol)? = nil,
        speechSynthesizer: (any SpeechSynthesizerProtocol)? = nil
    ) -> AssistViewModel {
        AssistViewModel(
            server: ServerFixture.standard,
            audioRecorder: mockAudioRecorder,
            audioPlayer: mockAudioPlayer,
            assistService: mockAssistService,
            autoStartRecording: autoStartRecording,
            speechTranscriber: speechTranscriber,
            speechSynthesizer: speechSynthesizer
        )
    }

    @MainActor
    func testOnAppearFetchPipelines() async throws {
        sut.initialRoutine()
        mockAssistService.pipelineResponse = .init(preferredPipeline: "", pipelines: [])
        XCTAssert(mockAssistService.fetchPipelinesCalled)
        XCTAssertEqual(AssistSession.shared.delegate.debugDescription, sut.debugDescription)
    }

    @MainActor
    func testOnAppearAutoStartRecording() async throws {
        sut = makeSut(autoStartRecording: true)
        mockAssistService.pipelineResponse = .init(preferredPipeline: "", pipelines: [])

        sut.initialRoutine()
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
        XCTAssertFalse(sut.autoStartRecording)
        XCTAssertEqual(sut.inputText, "")
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
    }

    @MainActor
    func testOnDisappear() async throws {
        sut = makeSut(autoStartRecording: true)

        sut.initialRoutine()
        sut.onDisappear()
        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
    }

    @MainActor
    func testAssistWithText() {
        sut.inputText = "How many lights are on?"
        sut.preferredPipelineId = "1"
        sut.pipelines = [.init(id: "1", name: "Pipeline")]
        sut.assistWithText()

        XCTAssertTrue(mockAudioPlayer.pauseCalled)
        XCTAssertFalse(sut.isRecording)
        XCTAssertFalse(sut.canSendAudioData)
        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
        XCTAssertTrue(mockAssistService.finishSendingAudioCalled)

        XCTAssertEqual(
            mockAssistService.assistSource,
            .text(input: "How many lights are on?", pipelineId: "1", expectTTS: false)
        )
        XCTAssertEqual(sut.inputText, "")
        XCTAssertEqual(sut.chatItems.first?.itemType, .input)
        XCTAssertEqual(sut.chatItems.first?.content, "How many lights are on?")
    }

    func testDidStartRecording() {
        sut.preferredPipelineId = "2"
        sut.didStartRecording(with: 16000)
        XCTAssertEqual(mockAssistService.assistSource, .audio(pipelineId: "2", audioSampleRate: 16000.0, tts: true))
    }

    func testDidStopRecording() {
        sut.didStopRecording()
        XCTAssertFalse(sut.isRecording)
    }

    func testDidReceiveRunEndEventWhenRecording() {
        sut.isRecording = true
        sut.didReceiveEvent(.runEnd)

        XCTAssertFalse(sut.isRecording)
        XCTAssertFalse(sut.canSendAudioData)
        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
        XCTAssertTrue(mockAssistService.finishSendingAudioCalled)
    }

    @MainActor
    func testDidReceiveIntentEndContent() {
        sut.didReceiveIntentEndContent("test")
        XCTAssertEqual(sut.chatItems.first?.content, "test")
        XCTAssertEqual(sut.chatItems.first?.itemType, .output)
    }

    @MainActor
    func testDidReceiveSttContent() {
        sut.didReceiveSttContent("test")
        XCTAssertEqual(sut.chatItems.first?.content, "test")
        XCTAssertEqual(sut.chatItems.first?.itemType, .input)
    }

    func testDidReceiveTtsMediaUrl() {
        sut.didReceiveTtsMediaUrl(URL(string: "https://google.com")!)

        XCTAssertEqual(mockAudioPlayer.playUrl, URL(string: "https://google.com")!)
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func testAudioPlayerDidFinishPlayingStartRecordingAgain() {
        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = true
        sut.audioPlayerDidFinishPlaying(AudioPlayer())

        XCTAssertEqual(sut.inputText, "")
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
    }

    func testAudioPlayerDidFinishPlayingNotStartRecordingAgain() {
        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = false
        sut.audioPlayerDidFinishPlaying(AudioPlayer())

        XCTAssertEqual(sut.inputText, "")
        XCTAssertFalse(mockAudioRecorder.startRecordingCalled)
    }

    func testVolumeIsZeroTriggersRecording() {
        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = true
        sut.volumeIsZero()

        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
    }

    func testVolumeIsZeroDoesNotTriggersRecording() {
        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = false
        sut.volumeIsZero()

        XCTAssertFalse(mockAudioRecorder.startRecordingCalled)
    }

    // MARK: - On-Device STT

    @MainActor
    func testOnDeviceSTT_assistWithAudio_setsIsRecordingAndCallsStartListening() async throws {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true

        sut.assistWithAudio()
        await Task.yield()

        XCTAssertTrue(sut.isRecording)
        XCTAssertTrue(mockTranscriber.startListeningCalled)
    }

    @MainActor
    func testOnDeviceSTT_assistWithAudio_whenRecordingWithText_submitsToAssist() {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true
        sut.isRecording = true
        sut.inputText = "Turn on the lights"

        sut.assistWithAudio()

        XCTAssertEqual(
            mockAssistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "", expectTTS: false)
        )
    }

    @MainActor
    func testOnDeviceSTT_assistWithAudio_whenRecordingWithEmptyText_stopsStreaming() {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true
        sut.isRecording = true
        sut.inputText = ""

        sut.assistWithAudio()

        XCTAssertFalse(sut.isRecording)
        XCTAssertTrue(mockTranscriber.stopListeningCalled)
    }

    @MainActor
    func testOnDeviceSTT_partialTranscript_updatesChatItemAndInputText() async throws {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true

        sut.assistWithAudio()
        await Task.yield()

        mockTranscriber.simulateTranscriptUpdate("Turn on", isFinal: false)

        XCTAssertEqual(sut.inputText, "Turn on")
        XCTAssertEqual(sut.chatItems.last?.itemType, .pending)
        XCTAssertEqual(sut.chatItems.last?.content, "Turn on")
    }

    @MainActor
    func testOnDeviceSTT_finalTranscript_submitsToAssistService() async throws {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true

        sut.assistWithAudio()
        await Task.yield()

        mockTranscriber.simulateTranscriptUpdate("Turn on the lights", isFinal: true)

        XCTAssertNotNil(mockAssistService.assistSource)
    }

    @MainActor
    func testOnDeviceSTT_transcribeError_stopsRecording() async throws {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true

        sut.assistWithAudio()
        await Task.yield()

        struct TestError: LocalizedError {
            var errorDescription: String? { "Test error" }
        }
        mockTranscriber.simulateError(TestError())

        XCTAssertFalse(sut.isRecording)
    }

    @MainActor
    func testOnDeviceSTT_listeningStateChangeFalse_setsIsRecordingFalse() async throws {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true

        sut.assistWithAudio()
        await Task.yield()

        mockTranscriber.simulateListeningStateChange(false)

        XCTAssertFalse(sut.isRecording)
    }

    @MainActor
    func testOnDeviceSTT_stopStreaming_callsStopListeningOnTranscriber() {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)

        sut.stopStreaming()

        XCTAssertTrue(mockTranscriber.stopListeningCalled)
    }

    @MainActor
    func testOnDeviceSTT_startListeningThrows_setsIsRecordingFalse() async throws {
        struct TestError: LocalizedError {
            var errorDescription: String? { "Permission denied" }
        }
        let mockTranscriber = MockSpeechTranscriber()
        mockTranscriber.startListeningError = TestError()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true

        sut.assistWithAudio()
        await Task.yield()

        XCTAssertFalse(sut.isRecording)
    }

    @MainActor
    func testOnDeviceSTT_pendingBubble_removedWhenStopStreamingCalled() async throws {
        let mockTranscriber = MockSpeechTranscriber()
        sut = makeSut(speechTranscriber: mockTranscriber)
        sut.configuration.enableOnDeviceSTT = true

        sut.assistWithAudio()
        await Task.yield()

        mockTranscriber.simulateTranscriptUpdate("Hel", isFinal: false)
        XCTAssertEqual(sut.chatItems.last?.itemType, .pending)

        sut.stopStreaming()

        XCTAssertNil(sut.chatItems.last.map { $0.itemType == .pending ? $0 : nil })
        XCTAssertNotEqual(sut.chatItems.last?.itemType, .pending)
    }

    // MARK: - On-Device TTS

    @MainActor
    func testOnDeviceTTS_didReceiveIntentEndContent_speaksWhenEnabled() {
        let mockSynthesizer = MockSpeechSynthesizer()
        sut = makeSut(speechSynthesizer: mockSynthesizer)
        sut.configuration.enableOnDeviceTTS = true
        sut.configuration.muteTTS = false

        sut.didReceiveIntentEndContent("Lights are on")

        XCTAssertTrue(mockSynthesizer.speakCalled)
        XCTAssertEqual(mockSynthesizer.lastSpokenText, "Lights are on")
    }

    @MainActor
    func testOnDeviceTTS_didReceiveIntentEndContent_doesNotSpeakWhenDisabled() {
        let mockSynthesizer = MockSpeechSynthesizer()
        sut = makeSut(speechSynthesizer: mockSynthesizer)
        sut.configuration.enableOnDeviceTTS = false

        sut.didReceiveIntentEndContent("Lights are on")

        XCTAssertFalse(mockSynthesizer.speakCalled)
    }

    @MainActor
    func testOnDeviceTTS_didReceiveIntentEndContent_doesNotSpeakWhenMuted() {
        let mockSynthesizer = MockSpeechSynthesizer()
        sut = makeSut(speechSynthesizer: mockSynthesizer)
        sut.configuration.enableOnDeviceTTS = true
        sut.configuration.muteTTS = true

        sut.didReceiveIntentEndContent("Lights are on")

        XCTAssertFalse(mockSynthesizer.speakCalled)
    }

    @MainActor
    func testOnDeviceTTS_assistWithText_doesNotRequestServerTTS() {
        let mockSynthesizer = MockSpeechSynthesizer()
        sut = makeSut(speechSynthesizer: mockSynthesizer)
        sut.configuration.enableOnDeviceTTS = true
        sut.configuration.muteTTS = false
        sut.inputText = "Turn on the lights"
        sut.preferredPipelineId = "1"

        sut.assistWithText(expectingTTS: true)

        XCTAssertEqual(
            mockAssistService.assistSource,
            .text(input: "Turn on the lights", pipelineId: "1", expectTTS: false)
        )
    }

    @MainActor
    func testOnDeviceTTS_onDisappear_stopsSynthesizer() {
        let mockSynthesizer = MockSpeechSynthesizer()
        sut = makeSut(speechSynthesizer: mockSynthesizer)

        sut.onDisappear()

        XCTAssertTrue(mockSynthesizer.stopCalled)
    }

    @MainActor
    func testOnDeviceTTS_onFinished_triggersRecordingAgainWhenNeeded() {
        let mockSynthesizer = MockSpeechSynthesizer()
        sut = makeSut(speechSynthesizer: mockSynthesizer)
        sut.configuration.enableOnDeviceTTS = true
        sut.configuration.muteTTS = false
        mockAssistService.shouldStartListeningAgainAfterPlaybackEnd = true

        sut.didReceiveIntentEndContent("Done")
        mockSynthesizer.simulateFinished()

        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
    }
}
