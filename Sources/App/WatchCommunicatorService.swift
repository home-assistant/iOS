import Communicator
import Foundation
import ObjectMapper
import PromiseKit
import Shared

final class WatchCommunicatorService {
    enum WatchAssistCommunicatorError: Error {
        case pipelinesFetchFailed
    }

    // Assist
    private var assistService: AssistServiceProtocol?
    private var pendingAudioData: Data?

    func setup() {
        Current.servers.add(observer: self)

        // This directly mutates the data structure for observations to avoid race conditions.
        Communicator.State.observations.store[.init(queue: .main)] = { state in
            Current.Log.verbose("Activation state changed: \(state)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        WatchState.observations.store[.init(queue: .main)] = { watchState in
            Current.Log.verbose("Watch state changed: \(watchState)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Reachability.observations.store[.init(queue: .main)] = { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        setupMessages()

        Blob.observations.store[.init(queue: .main)] = { [weak self] blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            if blob.identifier == InteractiveImmediateMessages.assistAudioData.rawValue {
                self?.assistAudioData(blob: blob)
            }
        }

        Context.observations.store[.init(queue: .main)] = { context in
            Current.Log.verbose("Received context: \(context.content.keys) \(context.content)")

            if let modelIdentifier = context.content[WatchContext.watchModel.rawValue] as? String {
                Current.crashReporter.setUserProperty(value: modelIdentifier, name: "PairedAppleWatch")
            }

            Current.apis.forEach({ $0.UpdateSensors(trigger: .watchContext).cauterize() })
        }

        _ = Communicator.shared
    }

    private func setupMessages() {
        InteractiveImmediateMessage.observations.store[.init(queue: .main)] = { [weak self] message in
            Current.Log.verbose("Received \(message.identifier) \(message) \(message.content)")

            guard let self, let messageId = InteractiveImmediateMessages(rawValue: message.identifier) else {
                Current.Log
                    .error(
                        "Received InteractiveImmediateMessage not mapped in InteractiveImmediateMessages: \(message.identifier)"
                    )
                return
            }

            switch messageId {
            case .ping:
                message.reply(.init(identifier: InteractiveImmediateResponses.pong.rawValue))
            case .watchConfig:
                watchConfig(message: message)
            case .actionRowPressed:
                actionRowPressed(message: message)
            case .pushAction:
                pushAction(message: message)
            case .assistPipelinesFetch:
                assistPipelinesFetch(message: message)
            case .assistAudioData:
                // This will be handled by Blob observation due to amount of data
                break
            case .magicItemPressed:
                magicItemPressed(message: message)
            }
        }
    }

    private func watchConfig(message: InteractiveImmediateMessage) {
        do {
            if let config: WatchConfig = try Current.watchGRDB().read({ db in
                try WatchConfig.fetchOne(db)
            }) {
                Current.Log.info("Watch configuration exists, moving forward providing it to watch")
                notifyWatchConfig(message: message, watchConfig: config)
            } else {
                Current.Log.error("No watch config found, notify watch of empty config")
                notifyEmptyWatchConfig(message: message)
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB) for watch config error: \(error.localizedDescription)")
        }
    }

    private func notifyWatchConfig(message: InteractiveImmediateMessage, watchConfig: WatchConfig) {
        let responseIdentifier = InteractiveImmediateResponses.watchConfigResponse.rawValue
        let magicItemProvider = Current.magicItemProvider()
        magicItemProvider.loadInformation {
            let magicItemsInfo: [MagicItem.Info] = watchConfig.items.map { magicItem in
                magicItemProvider.getInfo(for: magicItem)
            }
            message.reply(.init(identifier: responseIdentifier, content: [
                "config": watchConfig.encodeForWatch(),
                "magicItemsInfo": magicItemsInfo.map({ $0.encodeForWatch() }),
            ]))
        }
    }

    private func notifyEmptyWatchConfig(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue
        message.reply(.init(identifier: responseIdentifier))
    }

    private func magicItemPressed(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.magicItemRowPressedResponse.rawValue
        guard let itemType = message.content["itemType"] as? String,
              let itemId = message.content["itemId"] as? String,
              let serverId = message.content["serverId"] as? String,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let type = MagicItem.ItemType(rawValue: itemType) else {
            Current.Log.warning("Magic item press did not provide item type or item id")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        switch type {
        case .action:
            firstly {
                Current.api(for: server).HandleAction(actionID: itemId, source: .Watch)
            }.done {
                message.reply(.init(identifier: responseIdentifier, content: ["fired": true]))
            }.catch { err in
                Current.Log.error("Error during action event fire: \(err)")
                message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            }
        case .script:
            callService(
                server: server,
                message: message,
                magicItemId: itemId,
                domain: .script,
                responseIdentifier: responseIdentifier
            )
        case .scene:
            callService(
                server: server,
                message: message,
                magicItemId: itemId,
                domain: .scene,
                serviceName: "turn_on",
                serviceData: ["entity_id": itemId],
                responseIdentifier: responseIdentifier
            )
        }
    }

    private func callService(
        server: Server,
        message: InteractiveImmediateMessage,
        magicItemId: String,
        domain: Domain,
        serviceName: String? = nil,
        serviceData: [String: String] = [:],
        responseIdentifier: String
    ) {
        let domain = domain.rawValue
        let serviceName = serviceName ?? magicItemId.replacingOccurrences(of: "\(domain).", with: "")
        Current.api(for: server).CallService(
            domain: domain,
            service: serviceName,
            serviceData: serviceData,
            shouldLog: true
        ).pipe { result in
            switch result {
            case .fulfilled:
                message.reply(.init(identifier: responseIdentifier, content: ["fired": true]))
            case let .rejected(error):
                Current.Log.error("Failed to run \(domain), error: \(error.localizedDescription)")
                message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            }
        }
    }

    private func actionRowPressed(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.actionRowPressedResponse.rawValue
        guard let actionID = message.content["ActionID"] as? String,
              let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID),
              let server = Current.servers.server(for: action) else {
            Current.Log.warning("ActionID either does not exist or is not a string in the payload")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        firstly {
            Current.api(for: server).HandleAction(actionID: actionID, source: .Watch)
        }.done {
            message.reply(.init(identifier: responseIdentifier, content: ["fired": true]))
        }.catch { err in
            Current.Log.error("Error during action event fire: \(err)")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
        }
    }

    private func pushAction(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.pushActionResponse.rawValue

        if let infoJSON = message.content["PushActionInfo"] as? [String: Any],
           let info = Mapper<HomeAssistantAPI.PushActionInfo>().map(JSON: infoJSON),
           let serverIdentifier = message.content["Server"] as? String,
           let server = Current.servers.server(forServerIdentifier: serverIdentifier) {
            Current.backgroundTask(withName: "watch-push-action") { _ in
                firstly {
                    Current.api(for: server).handlePushAction(for: info)
                }.ensure {
                    message.reply(.init(identifier: responseIdentifier))
                }
            }.catch { error in
                Current.Log.error("error handling push action: \(error)")
            }
        }
    }

    private func sendMessage(message: ImmediateMessage) {
        Communicator.shared.send(message)
    }
}

// MARK: - Assist

extension WatchCommunicatorService {
    private func assistPipelinesFetch(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.assistPipelinesFetchResponse.rawValue

        let serverId = message.content["serverId"] as? String
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) ?? Current
            .servers.all.first else {
            Current.Log.warning("No server available to execute message \(message)")
            message.reply(.init(identifier: responseIdentifier, content: ["error": true]))
            return
        }

        initAssistServiceIfNeeded(server: server).fetchPipelines { pipelinesResponse in
            if let pipelines = pipelinesResponse?.pipelines,
               let preferredPipeline = pipelinesResponse?.preferredPipeline {
                message.reply(.init(identifier: responseIdentifier, content: [
                    "pipelines": pipelines.map({ pipeline in
                        [
                            "name": pipeline.name,
                            "id": pipeline.id,
                        ]
                    }),
                    "preferredPipeline": preferredPipeline,
                ]))
            } else {
                Current.Log
                    .error("Error during fetch Assist pipelines: \(WatchAssistCommunicatorError.pipelinesFetchFailed)")
                message.reply(.init(identifier: responseIdentifier, content: ["error": true]))
            }
        }
    }

    private func assistAudioData(blob: Blob) {
        let serverId = blob.metadata?["serverId"] as? String
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) ?? Current
            .servers.all.first else {
            let errorMessage = "No server available to execute message \(blob.identifier)"
            Current.Log.warning(errorMessage)
            return
        }

        let pipelineId = blob.metadata?["pipelineId"] as? String
        guard let sampleRate = blob.metadata?["sampleRate"] as? Double else {
            let errorMessage = "No sample rate received in message \(blob.identifier)"
            Current.Log.error(errorMessage)
            return
        }
        let audioData = blob.content
        pendingAudioData = audioData
        initAssistServiceIfNeeded(server: server).assist(source: .audio(
            pipelineId: pipelineId,
            audioSampleRate: sampleRate
        ))
    }

    private func initAssistServiceIfNeeded(server: Server) -> AssistServiceProtocol {
        if let assistService {
            assistService.replaceServer(server: server)
        } else {
            assistService = AssistService(server: server)
        }

        assistService?.delegate = self

        return assistService!
    }

    private func sendPendingAudioData() {
        if let pendingAudioData {
            assistService?.sendAudioData(pendingAudioData)
            /*
             Since Apple watch sends the whole audio all at once, we can notify
             the pipeline that the audio data flow ended
             */
            assistService?.finishSendingAudio()
            self.pendingAudioData = nil
        }
    }
}

// MARK: - AssistServiceDelegate

extension WatchCommunicatorService: AssistServiceDelegate {
    func didReceiveEvent(_ event: Shared.AssistEvent) {
        Current.Log.info("Watch Assist received event: \(event)")
    }

    func didReceiveSttContent(_ content: String) {
        let message = ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistSTTResponse.rawValue,
            content: [
                "content": content,
            ]
        )
        sendMessage(message: message)
    }

    func didReceiveIntentEndContent(_ content: String) {
        let message = ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistIntentEndResponse.rawValue,
            content: [
                "content": content,
            ]
        )
        sendMessage(message: message)
    }

    func didReceiveGreenLightForAudioInput() {
        sendPendingAudioData()
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        let message = ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistTTSResponse.rawValue,
            content: [
                "mediaURL": mediaUrl.absoluteString,
            ]
        )
        sendMessage(message: message)
    }

    func didReceiveError(code: String, message: String) {
        let message = ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistError.rawValue,
            content: [
                "code": code,
                "message": message,
            ]
        )
        sendMessage(message: message)
    }
}

// MARK: - ServerObserver

extension WatchCommunicatorService: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        _ = HomeAssistantAPI.SyncWatchContext()
    }
}
