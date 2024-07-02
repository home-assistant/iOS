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
    var replacedServer: Shared.Server?

    func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        fetchPipelinesCalled = true
        completion(pipelineResponse)
    }

    func replaceServer(server: Shared.Server) {
        replacedServer = server
    }

    func assist(source: AssistSource) {
        assistSource = source
    }

    func sendAudioData(_ data: Data) {
        sendAudioDataCalled = true
        audioDataSent = data
    }

    func finishSendingAudio() {
        finishSendingAudioCalled = true
    }
}
