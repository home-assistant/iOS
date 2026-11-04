import Combine
import Foundation
import PromiseKit
import Shared

enum WatchSendError: Error {
    case notImmediate
    case phoneFailed
    case wrongAudioURLData
    case watchScriptCallFailed
    case watchSceneCallFailed
}

final class WatchAssistService: ObservableObject {
    @Published var deviceReachable = false

    private let serverId: String
    private let pipelineId: String

    /// The server this Assist session talks to; playback needs it to present the server's
    /// client certificate and TLS security exceptions when fetching TTS audio.
    var server: Server? {
        Current.servers.server(forServerIdentifier: serverId)
    }

    private var reachabilityObservation: HAWatchConnectivity.ObservationToken?
    private var cancellable: Cancellable?
    /// The recording in progress, kept after it is submitted until the next one starts so the rest
    /// of it can still go out.
    private var audioStream: WatchAssistAudioStream?
    /// The whole recording being uploaded; a newer recording supersedes it.
    private var uploadingRecordingId: String?

    init(serverId: String, pipelineId: String) {
        self.serverId = serverId
        self.pipelineId = pipelineId
        setupReachability()
    }

    deinit {
        // Assist closed mid-recording: the iPhone drops the run instead of waiting for the rest.
        audioStream?.cancel()
        endRoutine()
    }

    func endRoutine() {
        if let reachabilityObservation {
            Communicator.shared.reachability.unobserve(reachabilityObservation)
            self.reachabilityObservation = nil
        }
    }

    /// Run the pipeline with a written prompt instead of a recording. The phone owns the WebSocket
    /// connection, so — exactly like the audio flow — it runs the pipeline and streams the response
    /// back through the immediate-message observers.
    func assist(text: String, completion: @escaping (Error?) -> Void) {
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            completion(WatchSendError.notImmediate)
            return
        }

        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.assistTextInput.rawValue,
            content: AssistTextInputPayload(
                text: text,
                pipelineId: pipelineId,
                serverId: serverId
            ).content,
            reply: { _ in
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        ), priority: .userAction, errorHandler: { error in
            Current.Log.error("Assist prompt failed to reach the iPhone: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(error)
            }
        })
    }

    /// Starts sending a recording while it is made: the iPhone hears the audio as the user speaks,
    /// and `onStopRecording` runs once it heard them stop. `onFailure` runs if the stream breaks.
    func beginAudio(
        sampleRate: Double,
        onStopRecording: @escaping () -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        audioStream?.cancel()
        uploadingRecordingId = nil
        let stream = WatchAssistAudioStream(
            sampleRate: sampleRate,
            pipelineId: pipelineId,
            serverId: serverId,
            phoneSupportsStreaming: phoneSupportsStreaming,
            send: { Self.send($0, timeout: $1, errorHandler: $2) }
        )
        stream.onStopRecording = onStopRecording
        stream.onFailure = onFailure
        audioStream = stream
        stream.start()
    }

    func appendAudio(_ audio: Data) {
        audioStream?.append(audio)
    }

    /// The recording ended: the end of a stream goes out, and a recording that was not streamed is
    /// uploaded whole. `onFailure` runs if the iPhone does not get it.
    func submitAudio(onFailure: @escaping (Error) -> Void) {
        guard let audioStream else { return }
        switch audioStream.submit() {
        case .sent:
            break
        case let .upload(recording):
            upload(audio: recording, sampleRate: audioStream.sampleRate) { error in
                if let error {
                    onFailure(error)
                }
            }
        }
    }

    /// The recording was dropped: the user was not asking anything.
    func cancelAudio() {
        audioStream?.cancel()
        audioStream = nil
    }

    /// The iPhone stopped listening to the stream `streamId`.
    func phoneStoppedListening(streamId: String) {
        guard audioStream?.id == streamId else { return }
        audioStream?.phoneStoppedListening()
    }

    /// An iPhone known to predate streaming gets the whole recording once it ends. One whose
    /// version is not known yet — nothing has come back from it since launch — is tried: a stream
    /// it does not answer falls back to the whole recording.
    private var phoneSupportsStreaming: Bool {
        let version = Communicator.shared.counterpartProtocolVersion ?? WatchProtocolVersion.assistAudioStream
        return version >= WatchProtocolVersion.assistAudioStream
    }

    private static func send(
        _ message: HAWatchConnectivity.InteractiveImmediateMessage,
        timeout: TimeInterval,
        errorHandler: @escaping (Error) -> Void
    ) {
        Communicator.shared.send(.init(
            identifier: message.identifier,
            content: message.content,
            reply: { reply in
                DispatchQueue.main.async {
                    message.reply(reply)
                }
            }
        ), timeout: timeout, priority: .userAction, errorHandler: { error in
            DispatchQueue.main.async {
                errorHandler(error)
            }
        })
    }

    /// Uploads a finished recording, for an iPhone that does not stream it.
    private func upload(audio audioData: Data, sampleRate: Double, completion: @escaping (Error?) -> Void) {
        cancellable?.cancel()
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            completion(WatchSendError.notImmediate)
            return
        }

        Current.Log.verbose("Signaling Assist audio data")

        let chunkSize = 32 * 1024 // 32 KB
        let totalChunks = max(1, Int(ceil(Double(audioData.count) / Double(chunkSize))))
        // Unique per recording so the phone never mixes chunks of an aborted/retried attempt into a
        // later one.
        let recordingId = UUID().uuidString
        uploadingRecordingId = recordingId
        sendChunk(
            index: 0,
            recordingId: recordingId,
            audioData: audioData,
            chunkSize: chunkSize,
            totalChunks: totalChunks,
            sampleRate: sampleRate,
            completion: completion
        )
    }

    /// Send one chunk, then the next only after the phone acknowledges it — backpressure instead of
    /// flooding the session — so a lost chunk surfaces as an error (reply timeout) rather than the
    /// phone waiting forever on a partial upload. `completion` fires exactly once, on the main queue:
    /// `nil` after the last ack, or the first delivery error.
    ///
    /// Ideally data transfers are done using an specific method to transfer data
    /// but in reality this has demonstrated to not work well specially in watchOS 26
    /// this logic uses the normal communication messages in chunks for more reliability.
    private func sendChunk(
        index: Int,
        recordingId: String,
        audioData: Data,
        chunkSize: Int,
        totalChunks: Int,
        sampleRate: Double,
        completion: @escaping (Error?) -> Void
    ) {
        let start = index * chunkSize
        let end = min(start + chunkSize, audioData.count)
        let chunkData = audioData.subdata(in: start ..< end)

        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.assistAudioDataChunked.rawValue,
            content: AssistAudioChunkPayload(
                chunkData: chunkData,
                chunkIndex: index,
                totalChunks: totalChunks,
                sampleRate: sampleRate,
                pipelineId: pipelineId,
                serverId: serverId,
                recordingId: recordingId
            ).content,
            reply: { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.uploadingRecordingId == recordingId else { return }
                    let next = index + 1
                    guard next < totalChunks else {
                        Current.Log.verbose("All \(totalChunks) assist audio chunk(s) acknowledged")
                        completion(nil)
                        return
                    }
                    self.sendChunk(
                        index: next,
                        recordingId: recordingId,
                        audioData: audioData,
                        chunkSize: chunkSize,
                        totalChunks: totalChunks,
                        sampleRate: sampleRate,
                        completion: completion
                    )
                }
            }
        ), priority: .userAction, errorHandler: { [weak self] error in
            Current.Log.error(
                "Assist audio chunk \(index + 1)/\(totalChunks) failed: \(error.localizedDescription)"
            )
            DispatchQueue.main.async {
                // A newer recording superseded this upload, so its failure is not the user's concern.
                guard let self, self.uploadingRecordingId == recordingId else { return }
                completion(error)
            }
        })
    }

    private func setupReachability() {
        reachabilityObservation = Communicator.shared.reachability.observe { [weak self] _ in
            DispatchQueue.main.async {
                self?.deviceReachable = Communicator.shared.currentReachability == .immediatelyReachable
            }
        }
        deviceReachable = Communicator.shared.currentReachability == .immediatelyReachable
    }
}
