import Communicator
import Foundation
import ObjectMapper
import PromiseKit
import Shared
import SwiftUI
import UIKit

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

    private var didBecomeActiveObserver: NSObjectProtocol?

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }

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

        // Present any client-certificate import the watch requested while the app was backgrounded.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.presentPendingClientCertImportIfPossible()
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
            case .pushAction:
                pushAction(message: message)
            case .assistPipelinesFetch:
                assistPipelinesFetch(message: message)
            case .assistAudioDataChunked:
                handleAssistAudioChunkedMessage(message)
            case .magicItemPressed:
                magicItemPressed(message: message)
            case .serversConfigSync:
                handleServersConfigSync(message: message)
            case .clientCertImportRequest:
                handleClientCertImportRequest(message: message)
            }
        }
    }

    private func handleServersConfigSync(message: InteractiveImmediateMessage) {
        // Reply with the server configuration AND any mTLS client certificate bundles inline,
        // mirroring how the watch configuration is delivered — a single, synchronous round-trip.
        var content: [String: Any] = ["servers": Current.servers.restorableState()]
        if let certificates = clientCertificateTransferData() {
            content["clientCertificates"] = certificates
        }
        message.reply(.init(
            identifier: InteractiveImmediateResponses.serversConfigSyncResponse.rawValue,
            content: content
        ))
    }

    // MARK: - mTLS client certificate transfer (phone → watch)

    /// Gather the client certificate bundle(s) for all configured servers, encoded as
    /// `[ClientCertificateTransferItem]`, to be delivered inline in the `serversConfigSync` reply.
    /// The watch has a separate Keychain, so the phone re-sends the original bundle + password.
    private func clientCertificateTransferData() -> Data? {
        let manager = ClientCertificateManager.shared

        let items: [ClientCertificateTransferItem] = Current.servers.all.compactMap { server in
            guard let cert = server.info.connection.clientCertificate else { return nil }
            return manager.transferMaterial(for: cert.keychainIdentifier)
        }

        // De-duplicate by identifier — the same certificate can be shared across servers.
        let unique = Array(
            Dictionary(items.map { ($0.keychainIdentifier, $0) }, uniquingKeysWith: { first, _ in first }).values
        )

        guard !unique.isEmpty else {
            Current.Log.info("[mTLS] No client certificate material available to include for watch")
            return nil
        }

        Current.Log.info("[mTLS] Including \(unique.count) client certificate(s) in watch reply")
        return try? JSONEncoder().encode(unique)
    }

    // MARK: - mTLS client certificate import (requested from the watch)

    private var pendingCertImportServerId: String?

    /// The watch asked us to present the client-certificate import screen for a server. We can't
    /// foreground the iPhone app from here, so remember the request and present it now (if the app
    /// is active) or the next time the app becomes active.
    private func handleClientCertImportRequest(message: InteractiveImmediateMessage) {
        pendingCertImportServerId = message.content["serverId"] as? String
        message.reply(.init(
            identifier: InteractiveImmediateResponses.clientCertImportRequestResponse.rawValue,
            content: ["acknowledged": true]
        ))
        DispatchQueue.main.async { [weak self] in
            self?.presentPendingClientCertImportIfPossible()
        }
    }

    private func presentPendingClientCertImportIfPossible() {
        guard let serverId = pendingCertImportServerId else { return }
        guard UIApplication.shared.applicationState == .active else {
            Current.Log.info("[mTLS] Client certificate import requested; will present when the app is active")
            return
        }
        guard let server = Current.servers.server(forServerIdentifier: serverId) else {
            Current.Log.error("[mTLS] Client certificate import requested for unknown server: \(serverId)")
            pendingCertImportServerId = nil
            return
        }
        guard let presenter = Self.topViewController(), presenter.presentedViewController == nil else {
            // Something is already presented; retry on the next activation.
            return
        }

        pendingCertImportServerId = nil
        Current.Log.info("[mTLS] Presenting client certificate import for server \(server.info.name)")

        let importView = ClientCertificateOnboardingView(
            onImport: { [weak presenter] certificate in
                server.update { $0.connection.clientCertificate = certificate }
                Current.Log.info("[mTLS] Imported client certificate on iPhone for watch: \(certificate.displayName)")
                presenter?.dismiss(animated: true)
            },
            onCancel: { [weak presenter] in
                presenter?.dismiss(animated: true)
            }
        )

        let host = UIHostingController(rootView: NavigationView { importView }.navigationViewStyle(.stack))
        host.modalPresentationStyle = .formSheet
        presenter.present(host, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
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
            var magicItemsInfo: [MagicItem.Info] = []

            // Collect info for all items, including those inside folders
            for magicItem in watchConfig.items {
                if let info = magicItemProvider.getInfo(for: magicItem) {
                    magicItemsInfo.append(info)
                }
                // If this is a folder, also get info for its children
                if magicItem.type == .folder, let folderItems = magicItem.items {
                    for folderItem in folderItems {
                        if let info = magicItemProvider.getInfo(for: folderItem) {
                            magicItemsInfo.append(info)
                        }
                    }
                }
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
              let type = MagicItem.ItemType(rawValue: itemType) else {
            Current.Log.warning("Magic item press did not provide item type or item id")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        // Folders don't execute actions, they are containers
        if type == .folder {
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        guard let serverId = message.content["serverId"] as? String,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            Current.Log.warning("Magic item press did not provide valid server info")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        switch type {
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
            guard let domain = MagicItem(id: itemId, serverId: serverId, type: .entity).domain,
                  let mainAction = domain.mainAction else {
                message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
                return
            }
            callService(
                server: server,
                message: message,
                magicItemId: itemId,
                domain: domain,
                serviceName: mainAction.rawValue,
                serviceData: ["entity_id": itemId],
                responseIdentifier: responseIdentifier
            )
        case .folder:
            // Already handled above, before server resolution
            break
        case .assistPipeline, .assistPrompt:
            // Assist items are not supported on Watch
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
        case .unsupported:
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
            audioSampleRate: sampleRate,
            tts: true
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
        // Servers + client certificates are delivered on demand via the `serversConfigSync` reply
        // (watch Home refresh); no proactive push needed here.
    }
}

private extension InteractiveImmediateMessage {
    func toImmediateMessage() -> ImmediateMessage {
        ImmediateMessage(identifier: identifier, content: content)
    }
}
