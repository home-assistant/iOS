import Communicator
import Foundation
import PromiseKit
import Shared

final class WatchAssistService: ObservableObject {
    @Published var servers: [Server] = []
    @Published var selectedServer: String = "" {
        didSet {
            pipelines = []
            preferredPipeline = ""

            // Fetch new pipelines in case server changes manually
            if !oldValue.isEmpty {
                fetchPipelines(completion: { _ in })
            }
        }
    }

    @Published var pipelines: [WatchPipeline] = []
    @Published var preferredPipeline: String = ""
    @Published var deviceReachable = false
    @Published var isFetchingPipeline = false

    private let watchPreferredServerUserDefaultsKey = "watch-preferred-server-id"
    private var reachabilityObservation: Observation?
    private var cancellable: Cancellable?

    init() {
        setupServers()
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

    func fetchPipelines(completion: @escaping (Bool) -> Void) {
        guard deviceReachable, !selectedServer.isEmpty else {
            completion(false)
            return
        }
        isFetchingPipeline = true
        Current.Log.verbose("Signaling fetch Assist pipelines via phone")
        let actionMessage = InteractiveImmediateMessage(
            identifier: InteractiveImmediateMessages.assistPipelinesFetch.rawValue,
            content: ["serverId": selectedServer],
            reply: { [weak self] message in
                Current.Log.verbose("Received reply dictionary \(message)")
                if let pipelines = message.content["pipelines"] as? [[String: String]] {
                    self?.updatePipelines(
                        pipelines,
                        preferredPipeline: message.content["preferredPipeline"] as? String
                    )
                    completion(true)
                } else {
                    completion(false)
                }
                self?.runInMainThread {
                    self?.isFetchingPipeline = false
                }
            }
        )

        Current.Log
            .verbose(
                "Sending \(InteractiveImmediateMessages.assistPipelinesFetch.rawValue) message \(actionMessage)"
            )
        Communicator.shared.send(actionMessage, errorHandler: { error in
            Current.Log.error("Received error when sending immediate message \(error)")
            completion(false)
        })
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

            var metadata: [String: Any] = [
                "sampleRate": sampleRate,
            ]

            if !preferredPipeline.isEmpty {
                metadata["pipelineId"] = preferredPipeline
            }

            if !selectedServer.isEmpty {
                metadata["serverId"] = selectedServer
            }

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

    private func updatePipelines(_ pipelines: [[String: String]], preferredPipeline: String?) {
        runInMainThread { [weak self] in
            guard let self else { return }
            self.pipelines = pipelines.compactMap({ pipelineRawValue in
                guard let id = pipelineRawValue["id"], let name = pipelineRawValue["name"] else {
                    return nil
                }
                return WatchPipeline(
                    id: id,
                    name: name
                )
            })
            self.preferredPipeline = preferredPipeline ?? ""
        }
    }

    private func setupServers() {
        servers = Current.servers.all
        if let preferredServer = UserDefaults().string(forKey: watchPreferredServerUserDefaultsKey),
           servers.first(where: { $0.identifier.rawValue == preferredServer }) != nil {
            selectedServer = preferredServer
        } else {
            if let server = Current.servers.all.first?.identifier.rawValue {
                selectedServer = server
            } else {
                selectedServer = ""
                Current.Log.error("Watch Assist: No server available, this can't happen")
            }
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

    private func runInMainThread(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            completion()
        }
    }
}
