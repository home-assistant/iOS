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

    /// One in-progress chunked audio upload from the watch.
    private struct AudioChunkSession {
        var chunks: [Int: Data] = [:]
        var totalChunks: Int
        var lastChunkAt: Date
    }

    /// In-progress audio uploads keyed by the watch's per-recording id (or `serverId_pipelineId`
    /// for watch builds that predate the recording id).
    private var audioChunkSessions: [String: AudioChunkSession] = [:]
    /// Partial uploads that stop receiving chunks for this long are abandoned (the watch retried or
    /// gave up) and dropped, so they can't leak memory or corrupt a later recording.
    private static let audioChunkSessionTimeout: TimeInterval = 60

    /// In-progress database syncs, keyed by transferId → the ordered chunks the watch pulls one by one.
    /// Only one sync is ever meaningful at a time (there is one paired watch), so starting a new sync
    /// frees any previous buffer — a watch that died mid-pull must not leak the encoded mirror.
    private var databaseSyncChunks: [String: [Data]] = [:]

    private var didBecomeActiveObserver: NSObjectProtocol?
    private var databaseUpdatedObserver: NSObjectProtocol?

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let databaseUpdatedObserver {
            NotificationCenter.default.removeObserver(databaseUpdatedObserver)
        }
    }

    func setup() {
        Current.servers.add(observer: self)

        // This directly mutates the data structure for observations to avoid race conditions.
        Communicator.shared.state.observations.store[.init(queue: .main)] = { state in
            Current.Log.verbose("Activation state changed: \(state)")
            HomeAssistantAPI.syncWatchContext()
        }

        Communicator.shared.watchState.observations.store[.init(queue: .main)] = { watchState in
            Current.Log.verbose("Watch state changed: \(watchState)")
            HomeAssistantAPI.syncWatchContext()
        }

        Communicator.shared.reachability.observations.store[.init(queue: .main)] = { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        setupMessages()

        // Background-delivery (transferUserInfo) requests from the watch. These arrive even when the
        // phone wasn't immediately reachable when the watch asked, so the config pull no longer depends
        // on the iPhone being foreground. Currently only the config pull uses this fallback.
        Communicator.shared.guaranteedMessage.observations.store[.init(queue: .main)] = { [weak self] message in
            guard let self, let messageId = InteractiveImmediateMessages(rawValue: message.identifier) else { return }
            Current.Log.verbose("Received guaranteed \(message.identifier)")
            presentWatchInteractionToast(for: messageId)
            if messageId == .watchConfig {
                respondToGuaranteedWatchConfigRequest()
            }
        }

        // When the iOS app finishes refreshing its local database from a server, proactively push the
        // updated reference tables to the watch over transferFile so its cached data stays fresh without
        // the user opening the watch app.
        databaseUpdatedObserver = NotificationCenter.default.addObserver(
            forName: .appDatabaseUpdaterDidFinishRoutine,
            object: nil,
            queue: .main
        ) { _ in
            WatchMirrorPushCoordinator.schedule(reason: .databaseUpdated)
        }

        // Present any client-certificate import the watch requested while the app was backgrounded.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.presentPendingClientCertImportIfPossible()
        }

        Communicator.shared.context.observations.store[.init(queue: .main)] = { context in
            Current.Log.verbose("Received context: \(context.content.keys) \(context.content)")

            if let modelIdentifier = context.content[WatchContext.watchModel.rawValue] as? String {
                Current.crashReporter.setUserProperty(value: modelIdentifier, name: "PairedAppleWatch")
            }

            Current.apis.forEach({ $0.UpdateSensors(trigger: .watchContext).cauterize() })
        }

        Communicator.shared.activate()
    }

    private func setupMessages() {
        Communicator.shared.interactiveImmediateMessage.observations
            .store[.init(queue: .main)] = { [weak self] message in
                Current.Log.verbose("Received \(message.identifier) \(message) \(message.content)")

                guard let self, let messageId = InteractiveImmediateMessages(rawValue: message.identifier) else {
                    Current.Log
                        .error(
                            "Received InteractiveImmediateMessage not mapped in InteractiveImmediateMessages: \(message.identifier)"
                        )
                    return
                }

                presentWatchInteractionToast(for: messageId)

                switch messageId {
                case .ping:
                    message.reply(.init(identifier: InteractiveImmediateResponses.pong.rawValue))
                case .watchConfig:
                    watchConfig(message: message)
                case .watchConfigAvailableItems:
                    watchConfigAvailableItems(message: message)
                case .watchConfigUpdate:
                    watchConfigUpdate(message: message)
                case .watchDatabaseMirror:
                    watchDatabaseMirrorSyncStart(message: message)
                case .watchDatabaseMirrorChunk:
                    watchDatabaseMirrorSyncChunk(message: message)
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

    /// Visual-only feedback: when the iPhone app is in the foreground and handles a request from the
    /// watch, surface a brief toast so the user can see the two devices talking. Silently skipped when
    /// the app isn't active (a toast wouldn't be visible) or on OS versions without the toast overlay.
    private func presentWatchInteractionToast(for messageId: InteractiveImmediateMessages) {
        // Skip keepalives and per-chunk pulls (the sync start already toasts) to avoid spamming.
        guard messageId != .ping, messageId != .watchDatabaseMirrorChunk else { return }
        guard #available(iOS 18, *) else { return }

        let message: String
        switch messageId {
        case .watchConfig, .watchConfigUpdate, .watchConfigAvailableItems:
            message = L10n.Watch.Interaction.Toast.config
        case .serversConfigSync, .clientCertImportRequest:
            message = L10n.Watch.Interaction.Toast.servers
        case .watchDatabaseMirror:
            message = L10n.Watch.Interaction.Toast.database
        case .magicItemPressed, .pushAction:
            message = L10n.Watch.Interaction.Toast.action
        default:
            message = L10n.Watch.Interaction.Toast.generic
        }

        Task { @MainActor in
            guard UIApplication.shared.applicationState == .active else { return }
            ToastPresenter.shared.show(
                id: "watch-interaction",
                symbol: .applewatch,
                symbolForegroundStyle: (.white, .haPrimary),
                title: L10n.Watch.Interaction.Toast.title,
                message: message,
                duration: 3
            )
        }
    }

    private func handleServersConfigSync(message: HAWatchConnectivity.InteractiveImmediateMessage) {
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
    private func handleClientCertImportRequest(message: HAWatchConnectivity.InteractiveImmediateMessage) {
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

    private func handleAssistAudioChunkedMessage(_ message: HAWatchConnectivity.InteractiveImmediateMessage) {
        guard let chunkData = message.content["chunkData"] as? Data,
              let chunkIndex = message.content["chunkIndex"] as? Int,
              let totalChunks = message.content["totalChunks"] as? Int,
              let serverId = message.content["serverId"] as? String,
              let pipelineId = message.content["pipelineId"] as? String else {
            Current.Log.error("Invalid chunked message data")
            return
        }
        // Older watch builds don't send a recordingId; fall back to the legacy key so they keep working.
        let sessionKey = (message.content["recordingId"] as? String) ?? (serverId + "_" + pipelineId)

        // Drop partial uploads that went quiet before starting/continuing this one.
        let now = Current.date()
        let staleKeys = audioChunkSessions.filter {
            now.timeIntervalSince($0.value.lastChunkAt) >= Self.audioChunkSessionTimeout
        }.keys
        for staleKey in staleKeys {
            Current.Log.warning("Dropping abandoned assist audio upload \(staleKey)")
            audioChunkSessions.removeValue(forKey: staleKey)
        }

        var session = audioChunkSessions[sessionKey]
            ?? AudioChunkSession(totalChunks: totalChunks, lastChunkAt: now)
        session.chunks[chunkIndex] = chunkData
        session.totalChunks = totalChunks
        session.lastChunkAt = now
        audioChunkSessions[sessionKey] = session

        // Acknowledge this chunk; the watch sends the next one only after receiving this.
        message.reply(.init(identifier: InteractiveImmediateResponses.assistAudioChunkAck.rawValue, content: [
            "acknowledged": true,
            "chunkIndex": chunkIndex,
            "totalChunks": totalChunks,
        ]))

        if session.chunks.count == totalChunks {
            let sortedChunks = session.chunks.keys.sorted().compactMap { session.chunks[$0] }
            let combinedData = sortedChunks.reduce(Data(), +)
            audioChunkSessions.removeValue(forKey: sessionKey)
            assistAudioData(message: message.toImmediateMessage(), data: combinedData)
        }
    }

    private func watchConfig(message: HAWatchConnectivity.InteractiveImmediateMessage) {
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

    private func notifyWatchConfig(message: HAWatchConnectivity.InteractiveImmediateMessage, watchConfig: WatchConfig) {
        buildWatchConfigResponseContent(watchConfig: watchConfig) { content in
            message.reply(.init(
                identifier: InteractiveImmediateResponses.watchConfigResponse.rawValue,
                content: content
            ))
        }
    }

    private func notifyEmptyWatchConfig(message: HAWatchConnectivity.InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue
        message.reply(.init(identifier: responseIdentifier))
    }

    /// Resolve the encoded config + magic-item info payload sent to the watch, shared by the interactive
    /// reply and the background (`transferUserInfo`) responder.
    private func buildWatchConfigResponseContent(
        watchConfig: WatchConfig,
        completion: @escaping ([String: Any]) -> Void
    ) {
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

            var content: [String: Any] = [
                "magicItemsInfo": magicItemsInfo.compactMap { try? $0.encodeForWatch() },
            ]
            do {
                content["config"] = try watchConfig.encodeForWatch()
            } catch {
                // Without the config key the watch treats the reply as a decode failure and keeps
                // its cached config — never as an authoritative empty one.
                Current.Log.error("Failed to encode watch config for reply: \(error.localizedDescription)")
            }
            completion(content)
        }
    }

    /// Background-delivery counterpart of `watchConfig(message:)`. The watch enqueues a
    /// `GuaranteedMessage` (backed by `transferUserInfo`) when the phone isn't immediately reachable;
    /// we answer the same way so the config survives the phone being backgrounded/locked. No
    /// reachability required on either side.
    private func respondToGuaranteedWatchConfigRequest() {
        // The types are spelled out: `.init` here is ambiguous between ImmediateMessage (requires
        // reachability — would defeat this whole flow) and GuaranteedMessage, and used to compile as
        // the latter only because Swift prefers the overload without defaulted arguments.
        do {
            if let config: WatchConfig = try Current.database().read({ db in try WatchConfig.fetchOne(db) }) {
                buildWatchConfigResponseContent(watchConfig: config) { content in
                    Communicator.shared.send(HAWatchConnectivity.GuaranteedMessage(
                        identifier: InteractiveImmediateResponses.watchConfigResponse.rawValue,
                        content: content
                    ))
                }
            } else {
                Communicator.shared.send(HAWatchConnectivity.GuaranteedMessage(
                    identifier: InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue
                ))
            }
        } catch {
            Current.Log.error("Failed to read watch config for guaranteed request: \(error.localizedDescription)")
        }
    }

    /// Build the list of items the user can add to the watch configuration and reply to the watch.
    /// Mirrors the iPhone watch picker (`MagicItemAddView` context `.watch`): scripts, scenes and
    /// automations, all stored as `type: .entity`.
    private func watchConfigAvailableItems(message: HAWatchConnectivity.InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.watchConfigAvailableItemsResponse.rawValue
        let allowedDomains: Set<String> = [
            Domain.script.rawValue,
            Domain.scene.rawValue,
            Domain.automation.rawValue,
        ]
        let magicItemProvider = Current.magicItemProvider()
        magicItemProvider.loadInformation { entitiesPerServer in
            let groups: [WatchConfigAvailableItems.ServerGroup] = Current.servers.all.map { server in
                let serverId = server.identifier.rawValue
                // The user picks the server before seeing entities, so drop the server prefix that
                // `getInfo` adds to the context line when multiple servers are configured.
                let serverPrefix = "\(server.info.name) • "
                let candidates: [WatchConfigAvailableItems.Candidate] = (entitiesPerServer[serverId] ?? [])
                    .filter { allowedDomains.contains($0.domain) }
                    .compactMap { entity in
                        let item = MagicItem(id: entity.entityId, serverId: serverId, type: .entity)
                        guard let info = magicItemProvider.getInfo(for: item) else { return nil }
                        let context = info.contextSubtitle.map { subtitle in
                            subtitle.hasPrefix(serverPrefix) ? String(subtitle.dropFirst(serverPrefix.count)) : subtitle
                        }
                        return .init(item: item, info: info, contextSubtitle: context)
                    }
                return .init(serverId: serverId, serverName: server.info.name, candidates: candidates)
            }
            let content: [String: Any]
            do {
                content = try ["availableItems": WatchConfigAvailableItems(servers: groups).encodeForWatch()]
            } catch {
                Current.Log.error("Failed to encode available items for watch: \(error.localizedDescription)")
                content = ["error": true]
            }
            message.reply(.init(identifier: responseIdentifier, content: content))
        }
    }

    /// Persist a `WatchConfig` edited on the watch. The phone's GRDB is the single source of truth,
    /// so we write it here (mirroring the iPhone `WatchConfigurationViewModel.save()`) and reply with
    /// the same payload as `watchConfig`, so the watch refreshes its cache with server-resolved info.
    /// On decode/DB failure we reply with the last-good persisted config, reverting the watch edit.
    private func watchConfigUpdate(message: HAWatchConnectivity.InteractiveImmediateMessage) {
        guard let data = message.content["config"] as? Data,
              var config = WatchConfig.decodeForWatch(data) else {
            Current.Log.error("Watch config update did not include a decodable config, reverting watch")
            watchConfig(message: message)
            return
        }
        do {
            try Current.database().write { db in
                if config.id != WatchConfig.watchConfigId {
                    try WatchConfig.deleteAll(db)
                    config.id = WatchConfig.watchConfigId
                }
                try config.insert(db, onConflict: .replace)
            }
            notifyWatchConfig(message: message, watchConfig: config)
        } catch {
            Current.Log.error("Failed to persist watch config sent from watch, error: \(error.localizedDescription)")
            watchConfig(message: message)
        }
    }

    /// Chunk size for the database sync. Comfortably under WatchConnectivity's per-message ceiling.
    private static let mirrorChunkByteSize = 30000

    /// Begin a full database sync: snapshot the reference GRDB tables, encode, split into ordered
    /// chunks held in memory, and tell the watch how many chunks/bytes to expect. The watch then pulls
    /// each chunk via `watchDatabaseMirrorChunk`. A single interactive reply here can exceed the size
    /// cap, which is exactly why the payload itself is chunked rather than returned inline.
    private func watchDatabaseMirrorSyncStart(message: HAWatchConnectivity.InteractiveImmediateMessage) {
        let responseId = InteractiveImmediateResponses.watchDatabaseMirrorResponse.rawValue
        if !databaseSyncChunks.isEmpty {
            Current.Log.info("Dropping \(databaseSyncChunks.count) abandoned watch DB sync buffer(s)")
            databaseSyncChunks.removeAll()
        }
        let data: Data
        do {
            data = try WatchDatabaseMirror.snapshot().encodeForWatch()
        } catch {
            Current.Log.error("Failed to build watch database mirror: \(error.localizedDescription)")
            message.reply(.init(identifier: responseId, content: ["error": true]))
            return
        }

        let chunkSize = Self.mirrorChunkByteSize
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            chunks.append(data.subdata(in: offset ..< end))
            offset = end
        }
        if chunks.isEmpty { chunks = [Data()] }

        let transferId = UUID().uuidString
        databaseSyncChunks[transferId] = chunks
        // Backstop for a watch that dies mid-pull and never starts another sync: a healthy pull
        // completes in seconds (each chunk request has a 30s reply ceiling and one timeout fails the
        // whole sync on the watch), so a buffer still around after this long is abandoned.
        DispatchQueue.main.asyncAfter(deadline: .now() + 600) { [weak self] in
            guard let self, databaseSyncChunks.removeValue(forKey: transferId) != nil else { return }
            Current.Log.info("Expired abandoned watch DB sync buffer \(transferId)")
        }
        Current.Log.info("Watch DB sync start: \(chunks.count) chunk(s), \(data.count) bytes, id \(transferId)")
        message.reply(.init(identifier: responseId, content: [
            "transferId": transferId,
            "totalChunks": chunks.count,
            "totalBytes": data.count,
        ]))
    }

    /// Serve one chunk of an in-progress database sync. The last chunk request frees the buffer.
    private func watchDatabaseMirrorSyncChunk(message: HAWatchConnectivity.InteractiveImmediateMessage) {
        let responseId = InteractiveImmediateResponses.watchDatabaseMirrorChunkResponse.rawValue
        guard let transferId = message.content["transferId"] as? String,
              let index = message.content["index"] as? Int,
              let chunks = databaseSyncChunks[transferId],
              index >= 0, index < chunks.count else {
            Current.Log.error("Invalid watch DB sync chunk request")
            message.reply(.init(identifier: responseId, content: ["error": true]))
            return
        }
        message.reply(.init(identifier: responseId, content: [
            "index": index,
            "chunkData": chunks[index],
        ]))
        if index == chunks.count - 1 {
            databaseSyncChunks.removeValue(forKey: transferId)
        }
    }

    private func magicItemPressed(message: HAWatchConnectivity.InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.magicItemRowPressedResponse.rawValue
        // Every failure reply carries a stable code (which the watch maps to a localized message)
        // plus the technical reason (which the watch records in client events) instead of a bare
        // `fired: false`.
        func fail(_ code: MagicItemExecutionFailureCode, _ reason: String) {
            message.reply(.init(identifier: responseIdentifier, content: [
                "fired": false,
                "errorCode": code.rawValue,
                "error": reason,
            ]))
        }

        if let triggeredAt = message.content["triggeredAt"] as? TimeInterval {
            let age = Current.date().timeIntervalSince1970 - triggeredAt
            if age > 30 {
                Current.Log.warning("Discarding stale magic item press received \(Int(age))s after it was triggered")
                fail(.staleRequest, "Request expired before reaching the iPhone (\(Int(age))s old)")
                return
            }
        }

        guard let itemType = message.content["itemType"] as? String,
              let itemId = message.content["itemId"] as? String,
              let type = MagicItem.ItemType(rawValue: itemType) else {
            Current.Log.warning("Magic item press did not provide item type or item id")
            fail(.invalidItem, "Invalid item type or id")
            return
        }

        // Folders don't execute actions, they are containers
        if type == .folder {
            fail(.notExecutable, "Folders don't execute actions")
            return
        }

        guard let serverId = message.content["serverId"] as? String,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            Current.Log.warning("Magic item press did not provide valid server info")
            fail(.serverNotFound, "Server not found on iPhone")
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
                fail(.notExecutable, "Entity domain has no executable action")
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
            fail(.notExecutable, "Assist items are not supported on Watch")
        case .unsupported:
            fail(.notExecutable, "Unsupported item type")
        }
    }

    private func callService(
        server: Server,
        message: HAWatchConnectivity.InteractiveImmediateMessage,
        magicItemId: String,
        domain: Domain,
        serviceName: String? = nil,
        serviceData: [String: String] = [:],
        responseIdentifier: String
    ) {
        guard let api = Current.api(for: server) else {
            message.reply(.init(identifier: responseIdentifier, content: [
                "fired": false,
                "errorCode": MagicItemExecutionFailureCode.noConnection.rawValue,
                "error": "iPhone has no usable connection for this server",
            ]))
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
                message.reply(.init(identifier: responseIdentifier, content: [
                    "fired": false,
                    "errorCode": MagicItemExecutionFailureCode.serviceCallFailed.rawValue,
                    "error": error.localizedDescription,
                ]))
            }
        }
    }

    private func pushAction(message: HAWatchConnectivity.InteractiveImmediateMessage) {
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

    private func sendMessage(message: HAWatchConnectivity.ImmediateMessage) {
        Communicator.shared.send(message)
    }
}

// MARK: - Assist

extension WatchCommunicatorService {
    private func assistPipelinesFetch(message: HAWatchConnectivity.InteractiveImmediateMessage) {
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
            } else if let cached = ((try? AssistPipelines.config()) ?? nil)?
                .first(where: { $0.serverId == server.identifier.rawValue }), !cached.pipelines.isEmpty {
                message.reply(.init(identifier: responseIdentifier, content: [
                    "pipelines": cached.pipelines.map { ["name": $0.name, "id": $0.id] },
                    "preferredPipeline": cached.preferredPipeline,
                ]))
            } else {
                Current.Log
                    .error("Error during fetch Assist pipelines: \(WatchAssistCommunicatorError.pipelinesFetchFailed)")
                message.reply(.init(identifier: responseIdentifier, content: ["error": true]))
            }
        }
    }

    private func assistAudioData(message: HAWatchConnectivity.ImmediateMessage, data: Data) {
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
        let message = HAWatchConnectivity.ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistSTTResponse.rawValue,
            content: [
                "content": content,
            ]
        )
        sendMessage(message: message)
    }

    func didReceiveIntentEndContent(_ content: String) {
        let message = HAWatchConnectivity.ImmediateMessage(
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
        let message = HAWatchConnectivity.ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistTTSResponse.rawValue,
            content: [
                "mediaURL": mediaUrl.absoluteString,
            ]
        )
        sendMessage(message: message)
    }

    func didReceiveError(code: String, message: String) {
        let message = HAWatchConnectivity.ImmediateMessage(
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
        HomeAssistantAPI.syncWatchContext()
        // Also push the reference database (which now carries the servers too) so the new server set
        // reaches the watch proactively. mTLS client-certificate bundles still flow only through the
        // on-demand `serversConfigSync` reply (they carry Keychain material kept off the mirror).
        WatchMirrorPushCoordinator.schedule(reason: .serversChanged)
    }
}

private extension HAWatchConnectivity.InteractiveImmediateMessage {
    func toImmediateMessage() -> HAWatchConnectivity.ImmediateMessage {
        HAWatchConnectivity.ImmediateMessage(identifier: identifier, content: content)
    }
}
