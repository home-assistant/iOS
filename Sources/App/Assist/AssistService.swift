import Foundation
import HAKit
import Shared

protocol AssistServiceProtocol {
    var delegate: AssistServiceDelegate? { get set }
    func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void)
    func assist(source: AssistSource)
    func sendAudioData(_ data: Data)
    func finishSendingAudio()
}

protocol AssistServiceDelegate: AnyObject {
    func didReceiveEvent(_ event: AssistEvent)
    func didReceiveSttContent(_ content: String)
    func didReceiveIntentEndContent(_ content: String)
    func didReceiveGreenLightForAudioInput()
    func didReceiveTtsMediaUrl(_ mediaUrl: URL)
}

enum AssistSource {
    case text(input: String, pipelineId: String)
    case audio(pipelineId: String, audioSampleRate: Double)
}

final class AssistService: AssistServiceProtocol {
    weak var delegate: AssistServiceDelegate?

    private let connection: HAConnection
    private let server: Server

    private var cancellable: HACancellable?
    private var sttBinaryHandlerId: UInt8?

    init(
        server: Server
    ) {
        self.server = server
        self.connection = Current.api(for: server).connection
    }

    deinit {
        cancellable?.cancel()
    }

    func assist(source: AssistSource) {
        switch source {
        case let .text(input, pipelineId):
            assistWithText(input: input, pipelineId: pipelineId)
        case let .audio(pipelineId, audioSampleRate):
            assistWithAudio(pipelineId: pipelineId, audioSampleRate: audioSampleRate)
        }
    }

    func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        connection.send(AssistRequests.fetchPipelinesTypedRequest) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(response):
                completion(response)
            case let .failure(error):
                Current.Log.error("Failed to fetch Assist pipelines: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    func sendAudioData(_ data: Data) {
        guard let sttBinaryHandlerId else { return }
        _ = connection.send(.init(
            type: .sttData(.init(sttBinaryHandlerId: sttBinaryHandlerId)),
            data: ["audioData": data.base64EncodedString()]
        ))
    }

    func finishSendingAudio() {
        guard let sttBinaryHandlerId else { return }
        _ = connection.send(.init(type: .sttData(.init(sttBinaryHandlerId: sttBinaryHandlerId))))
    }

    private func assistWithAudio(pipelineId: String, audioSampleRate: Double) {
        connection.subscribe(to: AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: pipelineId,
            audioSampleRate: audioSampleRate
        )) { [weak self] cancellable, data in
            guard let self else { return }
            self.cancellable = cancellable
            handleAssistEvent(data: data, cancellable: cancellable)
        }
    }

    private func assistWithText(input: String, pipelineId: String) {
        connection.subscribe(to: AssistRequests.assistByTextTypedSubscription(
            preferredPipelineId: pipelineId,
            inputText: input
        )) { [weak self] cancellable, data in
            guard let self else { return }
            self.cancellable = cancellable
            handleAssistEvent(data: data, cancellable: cancellable)
        }
    }

    private func handleAssistEvent(data: AssistResponse, cancellable: HACancellable) {
        Current.Log.info("Assist stage: \(data.type.rawValue)")
        Current.Log.info("Assist data: \(String(describing: data.data))")
        delegate?.didReceiveEvent(data.type)
        switch data.type {
        case .runStart:
            guard let sttBinaryHandlerId = data.data?.runnerData?.sttBinaryHandlerId else {
                Current.Log.error("No sttBinaryHandlerId on runStart")
                return
            }
            Current.Log.info("sttBinaryHandlerId: \(sttBinaryHandlerId)")
            self.sttBinaryHandlerId = UInt8(sttBinaryHandlerId)
            delegate?.didReceiveGreenLightForAudioInput()
        case .runEnd:
            sttBinaryHandlerId = nil
            cancellable.cancel()
        case .wakeWordStart:
            break
        case .wakeWordEnd:
            break
        case .sttStart:
            break
        case .sttVadStart:
            break
        case .sttVadEnd:
            break
        case .sttEnd:
            delegate?.didReceiveSttContent(data.data?.sttOutput?.text ?? "Unknown")
        case .intentStart:
            break
        case .intentEnd:
            delegate?.didReceiveIntentEndContent(data.data?.intentOutput?.response?.speech.plain.speech ?? "Unknown")
        case .ttsStart:
            break
        case .ttsEnd:
            guard let mediaUrlPath = data.data?.ttsOutput?.urlPath else { return }
            let mediaUrl = server.info.connection.activeURL().appendingPathComponent(mediaUrlPath)
            delegate?.didReceiveTtsMediaUrl(mediaUrl)
        case .error:
            sttBinaryHandlerId = nil
            Current.Log.error("Received error while interating with Assist: \(data)")
            cancellable.cancel()
        }
    }
}
