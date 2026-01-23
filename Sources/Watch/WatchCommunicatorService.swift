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

    // [sessionKey: [chunkIndex: Data]]
    private var audioChunks: [String: [Int: Data]] = [:]
    private var audioChunkCounts: [String: Int] = [:]

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
            case .assistAudioDataChunked:
                handleAssistAudioChunkedMessage(message)
            case .magicItemPressed:
                magicItemPressed(message: message)
            }
        }
    }

    private func handleAssistAudioChunkedMessage(_ message: InteractiveImmediateMessage) {
        guard let chunkData = message.content["chunkData"] as? Data,
              let chunkIndex = message.content["chunkIndex"] as? Int,
              let totalChunks = message.content["totalChunks"] as? Int,
              let serverId = message.content["serverId"] as? String,
              let pipelineId = message.content["pipelineId"] as? String else {
            Current.Log.error("Invalid chunked message data")
            return
        }
        let sessionKey = serverId + "_" + pipelineId
        if audioChunks[sessionKey] == nil {
            audioChunks[sessionKey] = [:]
        }
        audioChunks[sessionKey]?[chunkIndex] = chunkData
        audioChunkCounts[sessionKey] = totalChunks

        // Reply acknowledging receipt of this chunk
        message.reply(.init(identifier: "assistAudioChunkAck", content: [
            "acknowledged": true,
            "chunkIndex": chunkIndex,
            "totalChunks": totalChunks,
        ]))

        // Check if all chunks are received
        if let receivedChunks = audioChunks[sessionKey],
           receivedChunks.count == totalChunks {
            // Assemble data in order
            let sortedChunks = receivedChunks.keys.sorted().compactMap { receivedChunks[$0] }
            let combinedData = sortedChunks.reduce(Data(), +)
            // Clean up
            audioChunks.removeValue(forKey: sessionKey)
            audioChunkCounts.removeValue(forKey: sessionKey)
            // Call assistAudioData
            assistAudioData(message: message.toImmediateMessage(), data: combinedData)
        }
    }

    private func watchConfig(message: InteractiveImmediateMessage) {
        do {
            if let config: WatchConfig = try Current.database().read({ db in
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
        magicItemProvider.loadInformation { _ in
            let magicItemsInfo: [MagicItem.Info] = watchConfig.items.compactMap { magicItem in
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
              let type = MagicItem.ItemType(rawValue: itemType), let api = Current.api(for: server) else {
            Current.Log.warning("Magic item press did not provide item type or item id")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        switch type {
        case .action:
            firstly {
                api.HandleAction(actionID: itemId, source: .Watch)
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
                serviceName: Service.turnOn.rawValue,
                serviceData: ["entity_id": itemId],
                responseIdentifier: responseIdentifier
            )
        case .entity:
            guard let domain = MagicItem(id: itemId, serverId: "", type: .entity).domain else {
                message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
                return
            }
            callService(
                server: server,
                message: message,
                magicItemId: itemId,
                domain: domain,
                serviceName: Service.toggle.rawValue,
                serviceData: ["entity_id": itemId],
                responseIdentifier: responseIdentifier
            )
        case .folder:
            // Folders don't execute actions, they are containers
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
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
        guard let api = Current.api(for: server) else {
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            Current.Log.error("No API available to call service")
            return
        }
        let domain = domain.rawValue
        let serviceName = serviceName ?? magicItemId.replacingOccurrences(of: "\(domain).", with: "")
        api.CallService(
            domain: domain,
            service: serviceName,
            serviceData: serviceData,
            triggerSource: .Watch,
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
              let server = Current.servers.server(for: action),
              let api = Current.api(for: server) else {
            Current.Log.warning("ActionID either does not exist or is not a string in the payload")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        firstly {
            api.HandleAction(actionID: actionID, source: .Watch)
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
           let server = Current.servers.server(forServerIdentifier: serverIdentifier),
           let api = Current.api(for: server) {
            Current.backgroundTask(withName: BackgroundTask.watchPushAction.rawValue) { _ in
                firstly {
                    api.handlePushAction(for: info)
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

    private func assistAudioData(message: ImmediateMessage, data: Data) {
        let serverId = message.content["serverId"] as? String
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) ?? Current
            .servers.all.first else {
            let errorMessage = "No server available to execute message \(message.identifier)"
            Current.Log.warning(errorMessage)
            return
        }

        let pipelineId = message.content["pipelineId"] as? String
        guard let sampleRate = message.content["sampleRate"] as? Double else {
            let errorMessage = "No sample rate received in message \(message.identifier)"
            Current.Log.error(errorMessage)
            return
        }
        pendingAudioData = data
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
    func didReceiveStreamResponseChunk(_ content: String) {
        /* no-op */
    }

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

private extension InteractiveImmediateMessage {
    func toImmediateMessage() -> ImmediateMessage {
        ImmediateMessage(identifier: identifier, content: content)
    }
}
