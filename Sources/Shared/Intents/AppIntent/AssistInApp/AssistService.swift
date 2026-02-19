import Foundation
import GRDB
import HAKit

public protocol AssistServiceProtocol {
    var delegate: AssistServiceDelegate? { get set }
    var shouldStartListeningAgainAfterPlaybackEnd: Bool { get }
    func resetShouldStartListeningAgainAfterPlaybackEnd()
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
    /// LLMs supports streaming their response so it shows up word by word
    func didReceiveStreamResponseChunk(_ content: String)
    func didReceiveGreenLightForAudioInput()
    func didReceiveTtsMediaUrl(_ mediaUrl: URL)
    func didReceiveError(code: String, message: String)
}

public enum AssistSource: Equatable {
    case text(input: String, pipelineId: String?)
    case audio(pipelineId: String?, audioSampleRate: Double, tts: Bool)

    public static func == (lhs: AssistSource, rhs: AssistSource) -> Bool {
        switch (lhs, rhs) {
        case let (.text(lhsInput, lhsPipelineId), .text(rhsInput, rhsPipelineId)):
            return lhsInput == rhsInput && lhsPipelineId == rhsPipelineId
        case let (.audio(lhsPipelineId, lhsSampleRate, lhsTTS), .audio(rhsPipelineId, rhsSampleRate, rhsTTS)):
            return lhsPipelineId == rhsPipelineId && lhsSampleRate == rhsSampleRate && lhsTTS == rhsTTS
        default:
            return false
        }
    }
}

public final class AssistService: AssistServiceProtocol {
    public weak var delegate: AssistServiceDelegate?
    public var shouldStartListeningAgainAfterPlaybackEnd = false
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
    }

    deinit {
        cancellable?.cancel()
    }

    public func replaceServer(server: Server) {
        self.server = server
    }

    public func assist(source: AssistSource) {
        switch source {
        case let .text(input, pipelineId):
            assistWithText(input: input, pipelineId: pipelineId)
        case let .audio(pipelineId, audioSampleRate, tts):
            assistWithAudio(pipelineId: pipelineId, audioSampleRate: audioSampleRate, tts: tts)
        }
    }

    public func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        Current.api(for: server)?.connection.send(AssistRequests.fetchPipelinesTypedRequest) { [weak self] result in
            switch result {
            case let .success(response):
                self?.saveInDatabase(response)
                completion(response)
            case let .failure(error):
                Current.Log.error("Failed to fetch Assist pipelines: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    public func sendAudioData(_ data: Data) {
        guard let sttBinaryHandlerId else { return }
        _ = Current.api(for: server)?.connection.send(.init(
            type: .sttData(.init(rawValue: sttBinaryHandlerId)),
            data: ["audioData": data.base64EncodedString()]
        ))
    }

    public func finishSendingAudio() {
        guard let sttBinaryHandlerId else { return }
        _ = Current.api(for: server)?.connection.send(.init(type: .sttData(.init(rawValue: sttBinaryHandlerId))))
    }

    private func saveInDatabase(_ response: PipelineResponse) {
        do {
            let assistPipeline = AssistPipelines(serverId: server.identifier.rawValue, pipelineResponse: response)
            _ = try Current.database().write { db in
                try AssistPipelines.filter(
                    Column(DatabaseTables.AssistPipelines.serverId.rawValue) == server.identifier.rawValue
                ).deleteAll(db)
                try assistPipeline.save(db)
            }
        } catch {
            Current.Log.error("Failed to save Assist pipelines cache in database: \(error.localizedDescription)")
        }
    }

    private func assistWithAudio(pipelineId: String?, audioSampleRate: Double, tts: Bool) {
        lastPipelineIdUsed = pipelineId
        Current.api(for: server)?.connection.subscribe(to: AssistRequests.assistByVoiceTypedSubscription(
            preferredPipelineId: pipelineId,
            audioSampleRate: audioSampleRate,
            conversationId: conversationId,
            hassDeviceId: server.info.hassDeviceId,
            tts: tts
        )) { [weak self] cancellable, data in
            guard let self else { return }
            self.cancellable = cancellable
            handleAssistEvent(data: data, cancellable: cancellable)
        }
    }

    private func assistWithText(input: String, pipelineId: String?) {
        lastPipelineIdUsed = pipelineId
        Current.api(for: server)?.connection.subscribe(to: AssistRequests.assistByTextTypedSubscription(
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
            runStart(sttBinaryHandlerId: data.data?.runnerData?.sttBinaryHandlerId)
        case .runEnd:
            runEnd(cancellable: cancellable)
        case .sttEnd:
            sttEnd(content: data.data?.sttOutput?.text)
        case .intentEnd:
            intentEnd(
                conversationId: data.data?.intentOutput?.conversationId,
                content: data.data?.intentOutput?.response?.speech.plain.speech,
                continueConversation: (data.data?.intentOutput?.continueConversation).orFalse
            )
        case .ttsEnd:
            ttsEnd(mediaUrlPath: data.data?.ttsOutput?.urlPath)
        case .intentProgress:
            intentProgress(messageChunk: data.data?.chatLogDelta?.content)
        case .error:
            assistError(data: data, cancellable: cancellable)
        case .wakeWordStart, .wakeWordEnd, .sttStart, .sttVadStart, .sttVadEnd, .intentStart, .ttsStart:
            break
        case .unknown:
            Current.Log.verbose("Unmapped event received from Assist")
        }
    }

    public func resetShouldStartListeningAgainAfterPlaybackEnd() {
        shouldStartListeningAgainAfterPlaybackEnd = false
    }
}

// MARK: - Handling Assist events

extension AssistService {
    private func runStart(sttBinaryHandlerId: Int?) {
        guard let sttBinaryHandlerId else {
            Current.Log.error("No sttBinaryHandlerId on runStart")
            return
        }
        Current.Log.info("sttBinaryHandlerId: \(sttBinaryHandlerId)")
        self.sttBinaryHandlerId = UInt8(sttBinaryHandlerId)
        delegate?.didReceiveGreenLightForAudioInput()
    }

    private func runEnd(cancellable: HACancellable) {
        sttBinaryHandlerId = nil
        cancellable.cancel()
    }

    private func sttEnd(content: String?) {
        delegate?.didReceiveSttContent(content.orEmpty)
    }

    private func intentEnd(conversationId: String?, content: String?, continueConversation: Bool) {
        self.conversationId = conversationId
        delegate?.didReceiveIntentEndContent(content.orEmpty)
        shouldStartListeningAgainAfterPlaybackEnd = continueConversation
    }

    private func ttsEnd(mediaUrlPath: String?) {
        guard let mediaUrlPath,
              let mediaUrl = server.info.connection.activeURL()?.appendingPathComponent(mediaUrlPath) else { return }
        delegate?.didReceiveTtsMediaUrl(mediaUrl)
    }

    private func intentProgress(messageChunk: String?) {
        delegate?.didReceiveStreamResponseChunk(messageChunk.orEmpty)
    }

    private func assistError(data: AssistResponse, cancellable: HACancellable) {
        sttBinaryHandlerId = nil
        Current.Log.error("Received error while interating with Assist: \(data)")
        delegate?.didReceiveError(code: data.data?.code ?? "-1", message: data.data?.message ?? "Unknown error")
        cancellable.cancel()
    }
}
