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

    private let watchPreferredServerUserDefaultsKey = "watch-preferred-server-id"
    private var cancellable: AnyCancellable?

    init() {
        Current.servers.add(observer: self)
        self.cancellable = $selectedServer.sink { [weak self] newSelectedServer in
            guard let self else { return }
            UserDefaults().setValue(newSelectedServer, forKey: watchPreferredServerUserDefaultsKey)
            self.preferredPipeline = ""
            loadPipelines(serverId: newSelectedServer) { _ in }
        }
        setupServers()
    }

    deinit {
        cancellable?.cancel()
    }

    func fetchPipelines(completion: @escaping (Bool) -> Void) {
        loadPipelines(completion: completion)
    }

    func assist(audioURL: URL, sampleRate: Double, completion: @escaping (Bool) -> Void) {
        firstly { () -> Promise<Void> in
            Promise { [weak self] seal in
                guard let self else { return }
                guard Communicator.shared.currentReachability == .immediatelyReachable else {
                    seal.reject(WatchSendError.notImmediate)
                    return
                }

                let audioData = try Data(contentsOf: audioURL)

                Current.Log.verbose("Signaling Assist audio data")
                let blob = Blob(identifier: InteractiveImmediateMessages.assistAudioData.rawValue, content: audioData, metadata: [
                    "serverId": selectedServer,
                    "pipelineId": preferredPipeline,
                    "audioURL": audioURL.absoluteString,
                    "sampleRate": sampleRate,
                ])

                Current.Log
                    .verbose(
                        "Sending \(blob.identifier)"
                    )
                Communicator.shared.transfer(blob) { result in
                    switch result {
                    case .success:
                        seal.fulfill(())
                    case .failure(let error):
                        Current.Log.error("Failed to send audio data blob: \(error.localizedDescription)")
                        seal.reject(error)
                    }
                }
            }
        }
        .done {
            completion(true)
        }.catch { error in
            Current.Log.error("Error during sending Assist audio data: \(error)")
            completion(false)
        }
    }

    private func loadPipelines(serverId: String? = nil, completion: @escaping (Bool) -> Void) {
        let serverId = serverId ?? selectedServer
        firstly { () -> Promise<Void> in
            Promise { [weak self] seal in
                guard let self else { return }
                guard Communicator.shared.currentReachability == .immediatelyReachable else {
                    seal.reject(WatchSendError.notImmediate)
                    return
                }

                Current.Log.verbose("Signaling fetch Assist pipelines via phone")
                let actionMessage = InteractiveImmediateMessage(
                    identifier: InteractiveImmediateMessages.assistPipelinesFetch.rawValue,
                    content: ["serverId": serverId],
                    reply: { message in
                        Current.Log.verbose("Received reply dictionary \(message)")
                        if let pipelines = message.content["pipelines"] as? [[String: String]] {
                            self.updatePipelines(
                                pipelines,
                                preferredPipeline: message.content["preferredPipeline"] as? String ?? ""
                            )
                            seal.fulfill(())
                        } else {
                            seal.reject(WatchSendError.phoneFailed)
                        }
                    }
                )

                Current.Log
                    .verbose(
                        "Sending \(InteractiveImmediateMessages.assistPipelinesFetch.rawValue) message \(actionMessage)"
                    )
                Communicator.shared.send(actionMessage, errorHandler: { error in
                    Current.Log.error("Received error when sending immediate message \(error)")
                    seal.reject(error)
                })
            }
        }
        .done {
            completion(true)
        }.catch { err in
            Current.Log.error("Error during fetch Assist pipelines: \(err)")
            completion(false)
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
