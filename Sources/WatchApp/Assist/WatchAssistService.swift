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
    private var reachabilityObservation: HAWatchConnectivity.ObservationToken?
    private var cancellable: Cancellable?

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
