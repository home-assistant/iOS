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

            let metadata: [String: Any] = [
                "sampleRate": sampleRate,
                "pipelineId": pipelineId,
                "serverId": serverId,
            ]

            let blob = Blob(
                identifier: InteractiveImmediateMessages.assistAudioData.rawValue,
                content: audioData,
                metadata: metadata
            )

            Current.Log.verbose("Sending \(blob.identifier)")

            cancellable = Communicator.shared.transfer(blob) { result in
                switch result {
                case .success:
                    completion(nil)
                case let .failure(error):
                    Current.Log.error("Failed to send audio data blob: \(error.localizedDescription)")
                    completion(error)
                }
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
