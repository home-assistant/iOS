import Combine
import Communicator
import Foundation
import PromiseKit
import Shared

final class WatchAssistService: ObservableObject {
    @Published var servers: [Server] = []
    @Published var selectedServer: String = ""

    @Published var pipelines: [WatchPipeline] = []
    @Published var preferredPipeline: String = ""
    @Published var deviceReachable = false

    private let watchPreferredServerUserDefaultsKey = "watch-preferred-server-id"
    private var cancellable: AnyCancellable?
    private var reachabilityObservation: Observation?

    init() {
        Current.servers.add(observer: self)
        self.cancellable = $selectedServer.sink { [weak self] newSelectedServer in
            guard let self else { return }
            UserDefaults().setValue(newSelectedServer, forKey: watchPreferredServerUserDefaultsKey)
            self.preferredPipeline = ""
        }
        setupServers()
        self.reachabilityObservation = Reachability.observe { [weak self] state in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                switch state {
                case .immediatelyReachable:
                    self?.deviceReachable = true
                case .notReachable, .backgroundOnly:
                    self?.deviceReachable = false
                }
            }
        }
        self.deviceReachable = Communicator.shared.currentReachability == .immediatelyReachable
    }

    deinit {
        endRoutine()
    }

    func endRoutine() {
        cancellable?.cancel()
        if let reachabilityObservation {
            Reachability.unobserve(reachabilityObservation)
            self.reachabilityObservation = nil
        }
    }

    func fetchPipelines(completion: @escaping (Bool) -> Void) {
        guard deviceReachable else {
            completion(false)
            return
        }

        Current.Log.verbose("Signaling fetch Assist pipelines via phone")
        let actionMessage = InteractiveImmediateMessage(
            identifier: InteractiveImmediateMessages.assistPipelinesFetch.rawValue,
            content: ["serverId": selectedServer],
            reply: { message in
                Current.Log.verbose("Received reply dictionary \(message)")
                if let pipelines = message.content["pipelines"] as? [[String: String]] {
                    self.updatePipelines(
                        pipelines,
                        preferredPipeline: message.content["preferredPipeline"] as? String ?? ""
                    )
                    completion(true)
                } else {
                    completion(false)
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
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            completion(WatchSendError.notImmediate)
            return
        }

        do {
            let audioData = try Data(contentsOf: audioURL)
            try FileManager.default.removeItem(at: audioURL)

            Current.Log.verbose("Signaling Assist audio data")
            let blob = Blob(
                identifier: InteractiveImmediateMessages.assistAudioData.rawValue,
                content: audioData,
                metadata: [
                    "serverId": selectedServer,
                    "pipelineId": preferredPipeline,
                    "sampleRate": sampleRate,
                ]
            )

            Current.Log.verbose("Sending \(blob.identifier)")
            Communicator.shared.transfer(blob) { result in
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

    private func updatePipelines(_ pipelines: [[String: String]], preferredPipeline: String) {
        DispatchQueue.main.async { [weak self] in
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
            if self.preferredPipeline.isEmpty {
                self.preferredPipeline = preferredPipeline
            }
        }
    }

    private func setupServers() {
        servers = Current.servers.all
        if let preferredServer = UserDefaults().string(forKey: watchPreferredServerUserDefaultsKey),
           servers.first(where: { $0.identifier.rawValue == preferredServer }) != nil {
            selectedServer = preferredServer
        } else {
            selectedServer = Current.servers.all.first?.identifier.rawValue ?? ""
        }
    }
}

extension WatchAssistService: ServerObserver {
    func serversDidChange(_ serverManager: any Shared.ServerManager) {
        setupServers()
    }
}
