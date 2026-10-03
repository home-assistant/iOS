#if DEBUG
import Shared
import SwiftUI

/// TEMPORARY, CI screenshots only: opens Assist in a fixed state when the app is launched with an
/// `assist-screenshot=<state>` argument.
enum WatchAssistScreenshot {
    static var requestedState: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("assist-screenshot=") }?
            .replacingOccurrences(of: "assist-screenshot=", with: "")
    }

    static func view(for state: String) -> some View {
        WatchAssistView(viewModel: viewModel(for: state))
    }

    private static func viewModel(for state: String) -> WatchAssistViewModel {
        let service = WatchAssistService(serverId: "screenshot", pipelineId: "screenshot")
        service.endRoutine()
        service.deviceReachable = true
        let viewModel = WatchAssistViewModel(
            assistService: service,
            audioRecorder: ScreenshotRecorder(),
            audioPlayer: ScreenshotPlayer(),
            immediateCommunicatorService: ImmediateCommunicatorService()
        )
        viewModel.chatItems = [
            .init(content: "Turn on the kitchen lights", itemType: .input),
            .init(content: "Done, 3 lights are now on.", itemType: .output),
        ]
        switch state {
        case "recording-tap":
            viewModel.state = .recording
            viewModel.recordingSubmission = .tap
            viewModel.audioLevel = 0.6
        case "recording-release":
            viewModel.state = .recording
            viewModel.recordingSubmission = .release
            viewModel.audioLevel = 0.6
        case "cycle":
            // One launch walks through every state: relaunching brings up a permission alert.
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                viewModel.state = .recording
                viewModel.recordingSubmission = .tap
                viewModel.audioLevel = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                viewModel.recordingSubmission = .release
            }
        default:
            break
        }
        return viewModel
    }

    private final class ScreenshotRecorder: ObservableObject, WatchAudioRecorderProtocol {
        weak var delegate: WatchAudioRecorderDelegate?
        func startRecording() {}
        func stopRecording() {}
        func cancelRecording() {}
    }

    private final class ScreenshotPlayer: AudioPlayerProtocol {
        weak var delegate: AudioPlayerDelegate?
        func play(url: URL, server: Server?) {}
        func pause() {}
    }
}
#endif
