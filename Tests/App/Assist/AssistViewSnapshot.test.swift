@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct AssistViewSnapshotTests {
    /// Frozen so the listening orb's blobs land in the same place on every render.
    private static let orbFixedTime: TimeInterval = 100

    @available(iOS 18, *)
    @MainActor @Test func emptyConversation() {
        assert(makeViewModel(), named: "empty")
    }

    @available(iOS 18, *)
    @MainActor @Test func conversation() {
        let viewModel = makeViewModel()
        viewModel.chatItems = [
            .init(id: "1", content: "Preferred pipeline", itemType: .info),
            .init(id: "2", content: "Turn off the kitchen lights", itemType: .input),
            .init(id: "3", content: "Turned **2** lights off", itemType: .output),
            .init(id: "4", content: "Is the garage door closed?", itemType: .pending),
            .init(id: "5", content: "", itemType: .typing),
        ]
        assert(viewModel, named: "conversation")
    }

    @available(iOS 18, *)
    @MainActor @Test func error() {
        let viewModel = makeViewModel()
        viewModel.chatItems = [
            .init(id: "1", content: "Play something", itemType: .input),
            .init(id: "2", content: "Failed to connect to the server", itemType: .error),
        ]
        assert(viewModel, named: "error")
    }

    /// The action button turns into send once there is something to send.
    @available(iOS 18, *)
    @MainActor @Test func typedRequest() {
        let viewModel = makeViewModel()
        viewModel.inputText = "Turn on the porch light"
        assert(viewModel, named: "typed-request")
    }

    @available(iOS 18, *)
    @MainActor @Test func listening() {
        let viewModel = makeViewModel()
        viewModel.chatItems = [.init(id: "1", content: "Good morning", itemType: .input)]
        viewModel.isRecording = true
        viewModel.audioLevel = 0.6
        assert(viewModel, named: "listening")
    }

    /// A second pipeline is what puts the picker circle in the input row.
    @available(iOS 18, *)
    @MainActor @Test func pipelinesPicker() {
        let viewModel = makeViewModel()
        viewModel.pipelines = [
            .init(id: "home", name: "Home Assistant"),
            .init(id: "cloud", name: "Cloud"),
        ]
        viewModel.preferredPipelineId = "home"
        assert(viewModel, named: "pipelines-picker")
    }

    // MARK: - Helpers

    @MainActor
    private func makeViewModel() -> AssistViewModel {
        AssistViewModel(
            server: ServerFixture.standard,
            audioRecorder: MockAudioRecorder(),
            audioPlayer: MockAudioPlayer(),
            assistService: MockAssistService(),
            autoStartRecording: false
        )
    }

    @available(iOS 18, *)
    @MainActor
    private func assert(
        _ viewModel: AssistViewModel,
        named: String,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let view = AssistView(viewModel: viewModel)
            .environment(\.assistOrbFixedTime, Self.orbFixedTime)

        assertLightDarkSnapshots(
            of: view,
            // The screen is built from Liquid Glass and blurs, which the render server draws: a
            // layer-based capture comes back nearly empty.
            drawHierarchyInKeyWindow: true,
            named: named,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
