@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Renders Assist the way systems before Liquid Glass draw it (the snapshots cover the glass
/// look), for every kind of chat bubble, with the pipeline picker, while listening and without a
/// close button.
@Suite(.sharedState)
@MainActor
struct AssistViewLegacyAppearanceRenderTests {
    private func makeViewModel() -> AssistViewModel {
        AssistViewModel(
            server: ServerFixture.standard,
            audioRecorder: MockAudioRecorder(),
            audioPlayer: MockAudioPlayer(),
            assistService: MockAssistService(),
            autoStartRecording: false
        )
    }

    private func render(_ viewModel: AssistViewModel, showCloseButton: Bool = true) async {
        var dismissed = 0
        let controller = UIHostingController(rootView: AssistView(
            viewModel: viewModel,
            showCloseButton: showCloseButton,
            forcesLegacyAppearance: true,
            onDismiss: { dismissed += 1 }
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        for _ in 0 ..< 5 {
            await Task.yield()
        }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func rendersEveryBubble() async {
        let viewModel = makeViewModel()
        viewModel.chatItems = [
            .init(id: "1", content: "Preferred pipeline", itemType: .info),
            .init(id: "2", content: "Turn off the kitchen lights", itemType: .input),
            .init(id: "3", content: "Turned **2** lights off", itemType: .output),
            .init(id: "4", content: "Is the garage door closed?", itemType: .pending),
            .init(id: "5", content: "", itemType: .typing),
            .init(id: "6", content: "Failed to connect", itemType: .error),
        ]
        await render(viewModel)
        #expect(viewModel.chatItems.count >= 6)
    }

    @Test func rendersThePickerAndATypedRequest() async {
        let viewModel = makeViewModel()
        viewModel.pipelines = [
            .init(id: "home", name: "Home Assistant"),
            .init(id: "cloud", name: "Cloud"),
        ]
        viewModel.preferredPipelineId = "home"
        viewModel.inputText = "Turn on the porch light"
        await render(viewModel, showCloseButton: false)
    }

    @Test func rendersWhileListening() async {
        let viewModel = makeViewModel()
        viewModel.isRecording = true
        viewModel.audioLevel = 0.6
        await render(viewModel)
    }
}
