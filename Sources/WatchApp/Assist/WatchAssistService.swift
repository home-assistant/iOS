import Communicator
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
    private var reachabilityObservation: Observation?
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
            Reachability.unobserve(reachabilityObservation)
            self.reachabilityObservation = nil
        }
    }

    func assist(audioURL: URL, sampleRate: Double, completion: @escaping (Error?) -> Void) {
        cancellable?.cancel()
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            completion(WatchSendError.notImmediate)
            return
        }

        do {
            let audioData = try Data(contentsOf: audioURL)
            try FileManager.default.removeItem(at: audioURL)

            Current.Log.verbose("Signaling Assist audio data")

            let chunkSize = 32 * 1024 // 32 KB
            let totalChunks = Int(ceil(Double(audioData.count) / Double(chunkSize)))

            for chunkIndex in 0 ..< totalChunks {
                let start = chunkIndex * chunkSize
                let end = min(start + chunkSize, audioData.count)
                let chunkData = audioData.subdata(in: start ..< end)

                // Ideally data transfers are done using an specific method to transfer data
                // but in reality this has demonstrated to not work well specially in watchOS 26
                // this logic uses the normal communication messages in chunks for more reliability
                Communicator.shared.send(.init(
                    identifier: InteractiveImmediateMessages.assistAudioDataChunked.rawValue,
                    content: [
                        "chunkData": chunkData,
                        "chunkIndex": chunkIndex,
                        "totalChunks": totalChunks,
                        "sampleRate": sampleRate,
                        "pipelineId": pipelineId,
                        "serverId": serverId,
                    ],
                    reply: { message in
                        Current.Log.verbose("Received reply for assist audio chunk #\(chunkIndex): \(message)")
                    }
                ))
            }
        } catch {
            Current.Log.error("Watch assist failed: \(error.localizedDescription)")
            completion(error)
        }
    }

    private func setupReachability() {
        reachabilityObservation = Reachability.observe { [weak self] _ in
            DispatchQueue.main.async {
                self?.deviceReachable = Communicator.shared.currentReachability == .immediatelyReachable
            }
        }
        deviceReachable = Communicator.shared.currentReachability == .immediatelyReachable
    }
}
