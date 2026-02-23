@testable import HomeAssistant
@testable import Shared
import XCTest

final class AssistViewModelTests: XCTestCase {
    private var sut: AssistViewModel!
    private var mockAudioRecorder: MockAudioRecorder!
    private var mockAudioPlayer: MockAudioPlayer!
    private var mockAssistService: MockAssistService!
    private var mockSpeechTranscriber: MockSpeechTranscriber!

    override func setUp() async throws {
        mockAudioRecorder = MockAudioRecorder()
        mockAudioPlayer = MockAudioPlayer()
        mockAssistService = MockAssistService()
        mockSpeechTranscriber = MockSpeechTranscriber()

        sut = makeSut()
        AssistSession.shared.delegate = nil
        AssistSession.shared.inProgress = false
    }

    private func makeSut(autoStartRecording: Bool = false) -> AssistViewModel {
        AssistViewModel(
            server: ServerFixture.standard,
            audioRecorder: mockAudioRecorder,
            audioPlayer: mockAudioPlayer,
            assistService: mockAssistService,
            speechTranscriber: mockSpeechTranscriber,
            autoStartRecording: autoStartRecording
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

        XCTAssertEqual(mockAssistService.assistSource, .text(input: "How many lights are on?", pipelineId: "1"))
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

    // MARK: - On-Device STT Tests

    func testDidStartRecordingWithOnDeviceSTTEnabled() {
        sut.configuration.enableOnDeviceSTT = true
        sut.didStartRecording(with: 16000)

        XCTAssertTrue(sut.isUsingOnDeviceSTT)
        XCTAssertTrue(mockSpeechTranscriber.startTranscribingCalled)
        XCTAssertNil(mockAssistService.assistSource)
    }

    func testDidStartRecordingWithOnDeviceSTTDisabled() {
        sut.configuration.enableOnDeviceSTT = false
        sut.preferredPipelineId = "2"
        sut.didStartRecording(with: 16000)

        XCTAssertFalse(sut.isUsingOnDeviceSTT)
        XCTAssertFalse(mockSpeechTranscriber.startTranscribingCalled)
        XCTAssertEqual(mockAssistService.assistSource, .audio(pipelineId: "2", audioSampleRate: 16000.0, tts: true))
    }

    func testOnDeviceSTTUsesConfiguredLanguage() {
        sut.configuration.enableOnDeviceSTT = true
        sut.configuration.sttLanguage = "fr-FR"
        sut.didStartRecording(with: 16000)

        XCTAssertTrue(mockSpeechTranscriber.startTranscribingCalled)
        XCTAssertEqual(mockSpeechTranscriber.startLocale, Locale(identifier: "fr-FR"))
    }

    func testOnDeviceSTTUsesDeviceDefaultWhenLanguageEmpty() {
        sut.configuration.enableOnDeviceSTT = true
        sut.configuration.sttLanguage = ""
        sut.didStartRecording(with: 16000)

        XCTAssertTrue(mockSpeechTranscriber.startTranscribingCalled)
        XCTAssertEqual(mockSpeechTranscriber.startLocale, .current)
    }

    @MainActor
    func testSpeechTranscriberDidFinishSendsTextToAssist() {
        sut.configuration.enableOnDeviceSTT = true
        sut.preferredPipelineId = "1"
        sut.pipelines = [.init(id: "1", name: "Pipeline")]
        sut.didStartRecording(with: 16000)

        sut.speechTranscriberDidFinish(finalText: "Turn on the lights")

        XCTAssertEqual(mockAssistService.assistSource, .text(input: "Turn on the lights", pipelineId: "1"))
        XCTAssertEqual(sut.chatItems.first?.content, "Turn on the lights")
        XCTAssertEqual(sut.chatItems.first?.itemType, .input)
        XCTAssertFalse(sut.isUsingOnDeviceSTT)
    }

    @MainActor
    func testSpeechTranscriberDidFinishIgnoresEmptyText() {
        sut.configuration.enableOnDeviceSTT = true
        sut.didStartRecording(with: 16000)

        sut.speechTranscriberDidFinish(finalText: "   ")

        XCTAssertNil(mockAssistService.assistSource)
    }

    @MainActor
    func testSpeechTranscriberDidFailFallsBackToServer() {
        sut.configuration.enableOnDeviceSTT = true
        sut.didStartRecording(with: 16000)

        XCTAssertTrue(sut.isUsingOnDeviceSTT)

        sut.speechTranscriberDidFail(error: SpeechTranscriberError.recognizerUnavailable)

        XCTAssertFalse(sut.isUsingOnDeviceSTT)
        XCTAssertNotNil(mockAssistService.assistSource)
    }

    func testStopStreamingWithOnDeviceSTT() {
        sut.configuration.enableOnDeviceSTT = true
        sut.didStartRecording(with: 16000)
        XCTAssertTrue(sut.isUsingOnDeviceSTT)

        sut.stopStreaming()

        XCTAssertTrue(mockSpeechTranscriber.stopTranscribingCalled)
        XCTAssertFalse(sut.isUsingOnDeviceSTT)
        XCTAssertFalse(sut.isRecording)
    }

    func testStopStreamingWithoutOnDeviceSTT() {
        sut.configuration.enableOnDeviceSTT = false
        sut.stopStreaming()

        XCTAssertFalse(mockSpeechTranscriber.stopTranscribingCalled)
        XCTAssertTrue(mockAssistService.finishSendingAudioCalled)
    }
}
