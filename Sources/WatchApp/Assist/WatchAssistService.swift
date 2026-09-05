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

    /// The recording being streamed to the phone, if any. Created by the first `streamAudio` of a
    /// recording and released once it ended. Audio arrives on the capture queue while the
    /// recording is started and ended from the main queue, hence the lock.
    private var audioStreamer: WatchAssistAudioStreamer?
    private var isCapturingAudio = false
    private let audioStreamLock = NSLock()
    /// Fires when the pipeline stopped taking audio for the streamed recording: the recorder's
    /// cue to stop. Called on an arbitrary queue.
    var onAudioStreamStopListening: (() -> Void)?
    /// Fires when the streamed recording could not be delivered; the session is over. Called on
    /// an arbitrary queue.
    var onAudioStreamError: ((Error) -> Void)?

    init(serverId: String, pipelineId: String) {
        self.serverId = serverId
        self.pipelineId = pipelineId
        setupReachability()
    }

    deinit {
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

    /// Stream audio of the recording in progress to the phone. The first call of a recording
    /// starts the stream (and, on the phone, the pipeline run); the phone answers every chunk with
    /// whether the pipeline still listens, reported through `onAudioStreamStopListening`.
    func streamAudio(_ data: Data, sampleRate: Double) {
        audioStreamLock.lock()
        // A capture buffer can still land after the recording ended (the tap is removed without
        // waiting for one in flight): it must not open a new stream, and with it a new run.
        guard isCapturingAudio else {
            audioStreamLock.unlock()
            return
        }
        if audioStreamer == nil {
            guard Communicator.shared.currentReachability == .immediatelyReachable else {
                isCapturingAudio = false
                audioStreamLock.unlock()
                onAudioStreamError?(WatchSendError.notImmediate)
                return
            }
            Current.Log.verbose("Starting Assist audio stream")
            let streamer = WatchAssistAudioStreamer(
                serverId: serverId,
                pipelineId: pipelineId,
                sampleRate: sampleRate,
                sender: Communicator.shared
            )
            streamer.onStopListening = { [weak self] in
                self?.onAudioStreamStopListening?()
            }
            streamer.onError = { [weak self] error in
                self?.onAudioStreamError?(error)
            }
            audioStreamer = streamer
        }
        let streamer = audioStreamer
        audioStreamLock.unlock()
        streamer?.enqueue(audio: data)
    }

    /// The recorder started: audio handed to `streamAudio` from now until `endAudioStream`
    /// belongs to one recording.
    func beginAudioCapture() {
        audioStreamLock.lock()
        isCapturingAudio = true
        audioStreamer = nil
        audioStreamLock.unlock()
    }

    /// The recording ended on the watch: flush what is left and tell the phone the audio is
    /// complete. A no-op when nothing was streamed.
    func endAudioStream() {
        audioStreamLock.lock()
        isCapturingAudio = false
        let streamer = audioStreamer
        audioStreamer = nil
        audioStreamLock.unlock()
        streamer?.end()
    }

    /// Upload a finished recording in one go.
    ///
    /// - Note: Deprecated: `streamAudio` sends the audio while it is captured, so the pipeline's
    ///   own voice-activity detection ends the recording. Goes away with the ungating change.
    func assist(audioURL: URL, sampleRate: Double, completion: @escaping (Error?) -> Void) {
        cancellable?.cancel()
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            completion(WatchSendError.notImmediate)
            return
        }

        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
            try FileManager.default.removeItem(at: audioURL)
        } catch {
            Current.Log.error("Watch assist failed: \(error.localizedDescription)")
            completion(error)
            return
        }

        Current.Log.verbose("Signaling Assist audio data")

        let chunkSize = 32 * 1024 // 32 KB
        let totalChunks = max(1, Int(ceil(Double(audioData.count) / Double(chunkSize))))
        sendChunk(
            index: 0,
            // Unique per recording so the phone never mixes chunks of an aborted/retried attempt
            // into a later one.
            recordingId: UUID().uuidString,
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
                    let next = index + 1
                    guard next < totalChunks else {
                        Current.Log.verbose("All \(totalChunks) assist audio chunk(s) acknowledged")
                        completion(nil)
                        return
                    }
                    self?.sendChunk(
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
        ), priority: .userAction, errorHandler: { error in
            Current.Log.error(
                "Assist audio chunk \(index + 1)/\(totalChunks) failed: \(error.localizedDescription)"
            )
            DispatchQueue.main.async {
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
