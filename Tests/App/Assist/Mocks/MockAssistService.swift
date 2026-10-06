import Foundation
@testable import HomeAssistant
import Shared

final class MockAssistService: AssistServiceProtocol {
    weak var delegate: AssistServiceDelegate?
    var pipelineResponse: PipelineResponse?
    var fetchPipelinesCalled: Bool = false
    var sendAudioDataCalled: Bool = false
    var assistSource: AssistSource?
    var audioDataSent: Data?
    var finishSendingAudioCalled = false
    var cancelRunCalled = false
    /// Every chunk `sendAudioData` received, in order.
    var audioChunksSent: [Data] = []
    var replacedServer: Shared.Server?
    var shouldStartListeningAgainAfterPlaybackEnd: Bool = false
    var resetShouldStartListeningAgainAfterPlaybackEndCalled: Bool = false
    var holdsPipelinesCompletion = false
    /// Whether the last `assist(source:)` arrived on the main thread.
    var assistCalledOnMainThread: Bool?
    private var pendingPipelinesCompletions: [(PipelineResponse?) -> Void] = []

    func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        fetchPipelinesCalled = true
        if holdsPipelinesCompletion {
            pendingPipelinesCompletions.append(completion)
        } else {
            completion(pipelineResponse)
        }
    }

    /// Completes the oldest fetch still pending.
    func completePendingPipelinesFetch() {
        guard !pendingPipelinesCompletions.isEmpty else { return }
        pendingPipelinesCompletions.removeFirst()(pipelineResponse)
    }

    func replaceServer(server: Shared.Server) {
        replacedServer = server
    }

    func assist(source: AssistSource) {
        assistSource = source
        assistCalledOnMainThread = Thread.isMainThread
    }

    func sendAudioData(_ data: Data) {
        sendAudioDataCalled = true
        audioDataSent = data
        audioChunksSent.append(data)
    }

    func finishSendingAudio() {
        finishSendingAudioCalled = true
    }

    func cancelRun() {
        cancelRunCalled = true
    }

    func resetShouldStartListeningAgainAfterPlaybackEnd() {
        resetShouldStartListeningAgainAfterPlaybackEndCalled = true
    }
}
