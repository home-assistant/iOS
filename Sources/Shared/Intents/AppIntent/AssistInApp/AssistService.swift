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
    /// Abandons the run in progress without finishing its audio, so nothing heard so far is acted on.
    func cancelRun()
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
    case text(input: String, pipelineId: String?, expectTTS: Bool)
    case audio(pipelineId: String?, audioSampleRate: Double, tts: Bool)

    public var pipelineId: String? {
        switch self {
        case let .text(_, pipelineId, _), let .audio(pipelineId, _, _):
            return pipelineId
        }
    }

    public static func == (lhs: AssistSource, rhs: AssistSource) -> Bool {
        switch (lhs, rhs) {
        case let (.text(lhsInput, lhsPipelineId, lhsExpectTTS), .text(rhsInput, rhsPipelineId, rhsExpectTTS)):
            return lhsInput == rhsInput && lhsPipelineId == rhsPipelineId && lhsExpectTTS == rhsExpectTTS
        case let (.audio(lhsPipelineId, lhsSampleRate, lhsTTS), .audio(rhsPipelineId, rhsSampleRate, rhsTTS)):
            return lhsPipelineId == rhsPipelineId && lhsSampleRate == rhsSampleRate && lhsTTS == rhsTTS
        default:
            return false
        }
    }
}

public final class AssistService: AssistServiceProtocol {
    /// Reported when a voice run targets a pipeline the server cannot transcribe audio for.
    public static let speechToTextUnsupportedErrorCode = "stt-not-supported"

    public weak var delegate: AssistServiceDelegate?
    public var shouldStartListeningAgainAfterPlaybackEnd = false
    private var server: Server

    private var cancellable: HACancellable?
    private var sttBinaryHandlerId: UInt8?
    /// Bumped by every new or cancelled run, so a pipeline refresh only starts the run that asked for it.
    private var runGeneration = 0

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

    /// Callers have already settled where the user wants speech handled — a request transcribed on
    /// device arrives as text, and one spoken on device does not ask for TTS. What is left here is
    /// to not ask the pipeline for a stage it does not have, which the backend would reject before
    /// the run produced a single event.
    public func assist(source: AssistSource) {
        runGeneration += 1
        let generation = runGeneration
        let pipelineId = source.pipelineId
        let cached = cachedPipeline(id: pipelineId)

        // The cache can predate an engine added on the server since, and the watch and CarPlay start
        // runs without refreshing it, so a missing stage is confirmed with the server before acting on it.
        guard let cached, Self.stages(for: source, pipeline: cached) != Self.stages(for: source, pipeline: nil) else {
            start(source, pipeline: cached)
            return
        }
        fetchPipelines { [weak self] response in
            guard let self, generation == runGeneration else { return }
            let pipeline: Pipeline?
            if let response {
                pipeline = AssistPipelines(serverId: server.identifier.rawValue, pipelineResponse: response)
                    .pipeline(id: pipelineId)
            } else {
                pipeline = cached
            }
            start(source, pipeline: pipeline)
        }
    }

    private static func stages(for source: AssistSource, pipeline: Pipeline?) -> AssistRunStages? {
        switch source {
        case let .text(_, _, expectTTS):
            return AssistRunStages(pipeline: pipeline, listening: nil, speaking: expectTTS ? .server : nil)
        case let .audio(_, _, tts):
            return AssistRunStages(pipeline: pipeline, listening: .server, speaking: tts ? .server : nil)
        }
    }

    private func start(_ source: AssistSource, pipeline: Pipeline?) {
        guard let stages = Self.stages(for: source, pipeline: pipeline) else {
            reportSpeechToTextUnsupported()
            return
        }
        switch source {
        case let .text(input, pipelineId, _):
            assistWithText(input: input, pipelineId: pipelineId, expectTTS: stages.endsWithTextToSpeech)
        case let .audio(pipelineId, audioSampleRate, _):
            assistWithAudio(
                pipelineId: pipelineId,
                audioSampleRate: audioSampleRate,
                tts: stages.endsWithTextToSpeech
            )
        }
    }

    public func fetchPipelines(completion: @escaping (PipelineResponse?) -> Void) {
        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to fetch Assist pipelines: no API available for server")
            completion(nil)
            return
        }
        api.connection.send(AssistRequests.fetchPipelinesTypedRequest) { [weak self] result in
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

    /// Home Assistant cancels a pipeline run when its subscription is dropped.
    public func cancelRun() {
        // A run still waiting on its pipeline refresh must not start once that refresh lands.
        runGeneration += 1
        sttBinaryHandlerId = nil
        cancellable?.cancel()
        cancellable = nil
    }

    private func cachedPipeline(id pipelineId: String?) -> Pipeline? {
        AssistPipelines.cachedPipeline(id: pipelineId, serverId: server.identifier.rawValue)
    }

    /// Delivered on the main queue like a rejection from the backend would be, so callers that start
    /// a run from their recorder's callback have finished setting up before they hear it failed.
    private func reportSpeechToTextUnsupported() {
        Current.Log.error("Assist pipeline has no speech-to-text engine, not starting a voice run")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveError(
                code: Self.speechToTextUnsupportedErrorCode,
                message: L10n.Assist.Error.speechToTextUnsupported
            )
        }
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
        cancellable = Current.api(for: server)?.connection.subscribe(
            to: AssistRequests.assistByVoiceTypedSubscription(
                preferredPipelineId: pipelineId,
                audioSampleRate: audioSampleRate,
                conversationId: conversationId,
                hassDeviceId: server.info.hassDeviceId,
                tts: tts
            ),
            initiated: { [weak self] result in
                self?.handleSubscriptionInitiated(result)
            },
            handler: { [weak self] cancellable, data in
                guard let self else { return }
                self.cancellable = cancellable
                handleAssistEvent(data: data, cancellable: cancellable)
            }
        )
    }

    private func assistWithText(input: String, pipelineId: String?, expectTTS: Bool) {
        lastPipelineIdUsed = pipelineId
        cancellable = Current.api(for: server)?.connection.subscribe(
            to: AssistRequests.assistByTextTypedSubscription(
                preferredPipelineId: pipelineId,
                inputText: input,
                conversationId: conversationId,
                hassDeviceId: server.info.hassDeviceId,
                tts: expectTTS
            ),
            initiated: { [weak self] result in
                self?.handleSubscriptionInitiated(result)
            },
            handler: { [weak self] cancellable, data in
                guard let self else { return }
                self.cancellable = cancellable
                handleAssistEvent(data: data, cancellable: cancellable)
            }
        )
    }

    /// The backend can reject `assist_pipeline/run` outright — an unavailable STT provider on the
    /// pipeline (`stt-provider-missing`), an unknown pipeline id, a permission problem. That arrives
    /// as the subscription's *initial result*, not as a pipeline `error` event, so nothing reaches
    /// `handleAssistEvent`. Without this the run simply never produces anything: the watch stays on
    /// its "waiting for pipeline" spinner until its extended runtime session expires, and in-app
    /// Assist keeps its typing indicator forever. Report it like any other pipeline error so the UI
    /// can show the reason.
    private func handleSubscriptionInitiated(_ result: Result<HAData, HAError>) {
        guard case let .failure(error) = result else { return }
        sttBinaryHandlerId = nil
        Current.Log.error("Assist pipeline failed to start: \(error.localizedDescription)")
        // A rejected run is not retryable: HAKit keeps the subscription registered and re-sends it
        // on every reconnect, which would re-report the same failure for the rest of the session.
        cancellable?.cancel()
        cancellable = nil
        switch error {
        case let .external(externalError):
            delegate?.didReceiveError(code: externalError.code, message: externalError.message)
        case .internal, .underlying:
            delegate?.didReceiveError(
                code: "pipeline_run_failed",
                message: error.localizedDescription
            )
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
        // Evaluated against cached network information: this runs mid-pipeline over an active
        // WebSocket connection (so the cache is fresh), and delegates rely on receiving the TTS
        // URL synchronously, in order with the other pipeline events.
        guard let mediaUrlPath else {
            Current.Log.error("Assist tts-end event did not include a media URL path")
            delegate?.didReceiveError(
                code: "tts_missing_media_url",
                message: "The server did not return a TTS media URL"
            )
            return
        }
        guard let mediaUrl = server.activeURLUsingLastKnownNetworkState()?
            .appendingPathComponent(mediaUrlPath) else {
            Current.Log.error("Assist tts-end could not resolve an active server URL")
            delegate?.didReceiveError(
                code: "tts_no_active_url",
                message: "Could not resolve the server URL for TTS playback"
            )
            return
        }
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
