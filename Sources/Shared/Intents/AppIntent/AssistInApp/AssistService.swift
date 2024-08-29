import Foundation
import HAKit

public protocol AssistServiceProtocol {
    var delegate: AssistServiceDelegate? { get set }
    func replaceServer(server: Server)
    func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void)
    func assist(source: AssistSource)
    func sendAudioData(_ data: Data)
    func finishSendingAudio()
}

public protocol AssistServiceDelegate: AnyObject {
    func didReceiveEvent(_ event: AssistEvent)
    func didReceiveSttContent(_ content: String)
    func didReceiveIntentEndContent(_ content: String)
    func didReceiveGreenLightForAudioInput()
    func didReceiveTtsMediaUrl(_ mediaUrl: URL)
    func didReceiveError(code: String, message: String)
}

public enum AssistSource: Equatable {
    case text(input: String, pipelineId: String?)
    case audio(pipelineId: String?, audioSampleRate: Double)

    public static func == (lhs: AssistSource, rhs: AssistSource) -> Bool {
        switch (lhs, rhs) {
        case let (.text(lhsInput, lhsPipelineId), .text(rhsInput, rhsPipelineId)):
            return lhsInput == rhsInput && lhsPipelineId == rhsPipelineId
        case let (.audio(lhsPipelineId, lhsSampleRate), .audio(rhsPipelineId, rhsSampleRate)):
            return lhsPipelineId == rhsPipelineId && lhsSampleRate == rhsSampleRate
        default:
            return false
        }
    }
}

public final class AssistService: AssistServiceProtocol {
    public weak var delegate: AssistServiceDelegate?

    private var connection: HAConnection
    private var server: Server

    private var cancellable: HACancellable?
    private var sttBinaryHandlerId: UInt8?

    /// Conversation Id that is provided after first interation if available, this keeps context
    private var conversationId: String?
    /// This exists to reset conversationId when pipelineId changes
    private var lastPipelineIdUsed: String? {
        didSet {
            if oldValue != lastPipelineIdUsed {
                conversationId = nil
            }
        }
    }

    public init(
        server: Server
    ) {
        self.server = server
        self.connection = Current.api(for: server).connection
    }

    deinit {
        cancellable?.cancel()
    }

    public func replaceServer(server: Server) {
        self.server = server
        connection = Current.api(for: server).connection
    }

    public func assist(source: AssistSource) {
        switch source {
        case let .text(input, pipelineId):
            assistWithText(input: input, pipelineId: pipelineId)
        case let .audio(pipelineId, audioSampleRate):
            assistWithAudio(pipelineId: pipelineId, audioSampleRate: audioSampleRate)
        }
    }

    public func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        connection.send(AssistRequests.fetchPipelinesTypedRequest) { result in
            switch result {
            case let .success(response):
                completion(response)
            case let .failure(error):
                Current.Log.error("Failed to fetch Assist pipelines: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    public func sendAudioData(_ data: Data) {
        guard let sttBinaryHandlerId else { return }
        _ = connection.send(.init(
            type: .sttData(.init(rawValue: sttBinaryHandlerId)),
            data: ["audioData": data.base64EncodedString()]
        ))
    }

    public func finishSendingAudio() {
        guard let sttBinaryHandlerId else { return }
        _ = connection.send(.init(type: .sttData(.init(rawValue: sttBinaryHandlerId))))
    }

    private func assistWithAudio(pipelineId: String?, audioSampleRate: Double) {
        lastPipelineIdUsed = pipelineId
        connection.subscribe(to: AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: pipelineId,
            audioSampleRate: audioSampleRate,
            conversationId: conversationId,
            hassDeviceId: server.info.hassDeviceId
        )) { [weak self] cancellable, data in
            guard let self else { return }
            self.cancellable = cancellable
            handleAssistEvent(data: data, cancellable: cancellable)
        }
    }

    private func assistWithText(input: String, pipelineId: String?) {
        lastPipelineIdUsed = pipelineId
        connection.subscribe(to: AssistRequests.assistByTextTypedSubscription(
            preferredPipelineId: pipelineId,
            inputText: input,
            conversationId: conversationId,
            hassDeviceId: server.info.hassDeviceId
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
            conversationId = data.data?.intentOutput?.conversationId
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
            delegate?.didReceiveError(code: data.data?.code ?? "-1", message: data.data?.message ?? "Unknown error")
            cancellable.cancel()
        }
    }
}
