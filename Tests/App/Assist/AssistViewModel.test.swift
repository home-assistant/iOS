@testable import HomeAssistant
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

    private func makeSut(autoStartRecording: Bool = false) -> AssistViewModel {
        AssistViewModel(
            server: ServerFixture.standard,
            audioRecorder: mockAudioRecorder,
            audioPlayer: mockAudioPlayer,
            assistService: mockAssistService,
            autoStartRecording: autoStartRecording
        )
    }

    @MainActor
    func testOnAppearFetchPipelines() async throws {
        sut.initialRoutine()
        mockAssistService.pipelineResponse = .init(preferredPipeline: "", pipelines: [])
        try await sut.routineTask?.value
        XCTAssert(mockAssistService.fetchPipelinesCalled)
        XCTAssertEqual(AssistSession.shared.delegate.debugDescription, sut.debugDescription)
    }

    @MainActor
    func testOnAppearAutoStartRecording() async throws {
        sut = makeSut(autoStartRecording: true)
        mockAssistService.pipelineResponse = .init(preferredPipeline: "", pipelines: [])

        sut.initialRoutine()
        try await sut.routineTask?.value
        try await sut.audioTask?.value
        XCTAssertNotNil(sut.audioTask)
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
        XCTAssertFalse(sut.autoStartRecording)
        XCTAssertEqual(sut.inputText, "")
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
    }

    @MainActor
    func testOnDisappear() async throws {
        sut = makeSut(autoStartRecording: true)

        sut.initialRoutine()
        try await sut.routineTask?.value
        try await sut.audioTask?.value
        sut.onDisappear()
        XCTAssertTrue(mockAudioRecorder.stopRecordingCalled)
        XCTAssertTrue(mockAudioPlayer.pauseCalled)
        XCTAssertTrue(sut.audioTask!.isCancelled)
        XCTAssertTrue(sut.routineTask!.isCancelled)
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
        XCTAssertEqual(mockAssistService.assistSource, .audio(pipelineId: "2", audioSampleRate: 16000.0))
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
}
