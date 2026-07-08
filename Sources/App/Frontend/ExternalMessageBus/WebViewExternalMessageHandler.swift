import CoreBluetooth
import Foundation
import Improv_iOS
import PromiseKit
import SFSafeSymbols
@preconcurrency import Shared
import SwiftUI

// MARK: - Protocol

protocol WebViewExternalMessageHandlerProtocol {
    var webViewController: WebViewControllerProtocol? { get set }
    func handleExternalMessage(_ dictionary: [String: Any])
    func sendExternalBus(message: WebSocketMessage) -> Promise<Void>
    func sendExternalBusCommandWithRetry(command: WebViewExternalBusOutgoingMessage, payload: [String: Any]?)

    // TODO: Move these methods below to their proper handlers
    func scanImprov()
    func stopImprovScanIfNeeded()
    func showAssist(server: Server, pipeline: String, autoStartRecording: Bool)
}

final class WebViewExternalMessageHandler: @preconcurrency WebViewExternalMessageHandlerProtocol {
    weak var webViewController: WebViewControllerProtocol?
    private let improvManager: any ImprovManagerProtocol
    private lazy var entityAddToHandler: EntityAddToHandler = .init(webViewController: webViewController)

    private var improvController: UIViewController?

    private var nextOutgoingMessageID = 1
    private var pendingCommands: [Int: PendingExternalBusCommand] = [:]

    init(
        improvManager: any ImprovManagerProtocol
    ) {
        self.improvManager = improvManager
    }

    // swiftlint:disable cyclomatic_complexity
    @MainActor
    func handleExternalMessage(_ dictionary: [String: Any]) {
        guard let webViewController else {
            Current.Log.error("WebViewExternalMessageHandler has nil webViewController")
            return
        }
        guard let incomingMessage = WebSocketMessage(dictionary) else {
            Current.Log.error("Received invalid external message \(dictionary)")
            return
        }

        if incomingMessage.MessageType == "result" {
            handleExternalBusCommandResult(incomingMessage)
            return
        }

        var response: Guarantee<WebSocketMessage>?

        if let externalBusMessage = WebViewExternalBusMessage(rawValue: incomingMessage.MessageType) {
            switch externalBusMessage {
            case .configGet:
                let configResult = WebViewExternalBusMessage.configResult
                response = Guarantee { seal in
                    DispatchQueue.global(qos: .userInitiated).async {
                        seal(WebSocketMessage(
                            id: incomingMessage.ID!,
                            type: "result",
                            result: configResult
                        ))
                    }
                }
            case .configScreenShow:
                showSettingsViewController()
            case .haptic:
                guard let hapticType = incomingMessage.Payload?["hapticType"] as? String else {
                    Current.Log.error("Received haptic via bus but hapticType was not string! \(incomingMessage)")
                    return
                }
                handleHaptic(hapticType)
            case .connectionStatus:
                guard let connEvt = incomingMessage.Payload?["event"] as? String else {
                    Current.Log.error("Received connection-status via bus but event was not string! \(incomingMessage)")
                    return
                }
                webViewController.updateFrontendConnectionState(state: connEvt)
            case .tagRead:
                response = Current.tags.readNFC().map { tag in
                    WebSocketMessage(id: incomingMessage.ID!, type: "result", result: ["success": true, "tag": tag])
                }.recover { _ in
                    .value(WebSocketMessage(id: incomingMessage.ID!, type: "result", result: ["success": false]))
                }
            case .tagWrite:
                let (promise, seal) = Guarantee<Bool>.pending()
                response = promise.map { success in
                    WebSocketMessage(id: incomingMessage.ID!, type: "result", result: ["success": success])
                }

                firstly { () throws -> Promise<(tag: String, name: String?)> in
                    if let tag = incomingMessage.Payload?["tag"] as? String, tag.isEmpty == false {
                        return .value((tag: tag, name: incomingMessage.Payload?["name"] as? String))
                    } else {
                        throw HomeAssistantAPI.APIError.invalidResponse
                    }
                }.then { tagInfo in
                    Current.tags.writeNFC(value: tagInfo.tag)
                }.done { _ in
                    Current.Log.info("wrote tag via external bus")
                    seal(true)
                }.catch { error in
                    Current.Log.error("couldn't write tag via external bus: \(error)")
                    seal(false)
                }
            case .themeUpdate:
                webViewController.evaluateJavaScript("notifyThemeColors()", completion: nil)
            case .matterCommission:
                matterComissioningHandler(incomingMessage: incomingMessage)
            case .threadImportCredentials:
                transferKeychainThreadCredentialsToHARequested()
            case .barCodeScanner:
                guard let title = incomingMessage.Payload?["title"] as? String,
                      let description = incomingMessage.Payload?["description"] as? String,
                      let incomingMessageId = incomingMessage.ID else { return }
                barcodeScannerRequested(
                    title: title,
                    description: description,
                    alternativeOptionLabel: incomingMessage.Payload?["alternative_option_label"] as? String,
                    incomingMessageId: incomingMessageId
                )
            case .barCodeScannerClose:
                if webViewController.overlayedController as? BarcodeScannerHostingController != nil {
                    webViewController.dismissControllerAboveOverlayController()
                    webViewController.dismissOverlayController(animated: true, completion: nil)
                }
            case .barCodeScannerNotify:
                guard let message = incomingMessage.Payload?["message"] as? String else { return }
                presentBarcodeScannerMessage(message: message)
            case .threadStoreCredentialInAppleKeychain:
                guard let macExtendedAddress = incomingMessage.Payload?["mac_extended_address"] as? String,
                      let activeOperationalDataset = incomingMessage.Payload?["active_operational_dataset"] as? String else { return }
                transferHAThreadCredentialsToKeychain(
                    macExtendedAddress: macExtendedAddress,
                    activeOperationalDataset: activeOperationalDataset
                )
            case .assistShow:
                let startListening = incomingMessage.Payload?["start_listening"] as? Bool
                let pipelineId = incomingMessage.Payload?["pipeline_id"] as? String
                showAssist(
                    server: webViewController.server,
                    pipeline: pipelineId ?? "",
                    autoStartRecording: startListening ?? false
                )
            case .assistSettings:
                showAssistSettingsViewController()
            case .scanForImprov:
                scanImprov()
            case .improvConfigureDevice:
                let deviceName = incomingMessage.Payload?["name"] as? String
                presentImprov(deviceName: deviceName)
            case .focusElement:
                guard let elementId = incomingMessage.Payload?["element_id"] as? String else {
                    Current.Log
                        .error("Received focus_element via bus but element_id was not string! \(incomingMessage)")
                    return
                }
                handleElementFocus(elementId: elementId)
            case .toastShow:
                guard let toastPayload = ToastShowPayload(payload: incomingMessage.Payload) else {
                    Current.Log
                        .error("Received toast/show via bus but missing or invalid parameters! \(incomingMessage)")
                    return
                }
                showToast(payload: toastPayload)
            case .toastHide:
                guard let toastPayload = ToastHidePayload(payload: incomingMessage.Payload) else {
                    Current.Log.error("Received toast/hide via bus but id was not string! \(incomingMessage)")
                    return
                }
                hideToast(id: toastPayload.id)
            case .entityAddToGetActions:
                guard let entityId = incomingMessage.Payload?["entity_id"] as? String else {
                    Current.Log
                        .error("Received entity/add_to/get_actions but entity_id was not string! \(incomingMessage)")
                    return
                }
                response = handleGetEntityAddToActions(entityId: entityId, messageId: incomingMessage.ID)
            case .entityAddTo:
                guard let entityId = incomingMessage.Payload?["entity_id"] as? String,
                      let appPayload = incomingMessage.Payload?["app_payload"] as? String else {
                    Current.Log.error("Received entity/add_to but missing entity_id or app_payload! \(incomingMessage)")
                    return
                }
                handleEntityAddTo(entityId: entityId, appPayload: appPayload)
            case .cameraPlayerShow:
                guard let entityId = incomingMessage.Payload?["entity_id"] as? String else {
                    Current.Log.error("Received camera/show but entity_id was not string! \(incomingMessage)")
                    return
                }
                showCameraPlayer(entityId: entityId, cameraName: incomingMessage.Payload?["camera_name"] as? String)
            }
        } else {
            Current.Log.error("unknown: \(incomingMessage.MessageType)")
        }

        response?.then { [self] outgoing in
            sendExternalBus(message: outgoing)
        }.cauterize()
    }

    // swiftlint:enable cyclomatic_complexity

    func showSettingsViewController() {
        Current.sceneManager.appCoordinator.done { $0.showSettings() }
    }

    @MainActor
    private func showAssistSettingsViewController() {
        Current.sceneManager.appCoordinator.done { $0.showAssistSettings() }
    }

    func handleHaptic(_ hapticType: String) {
        Current.Log.verbose("Handle haptic type \(hapticType)")
        switch hapticType {
        case "success":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "error", "failure":
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case "warning":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case "light":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "medium":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "heavy":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "selection":
            UISelectionFeedbackGenerator().selectionChanged()
        default:
            Current.Log.verbose("Unknown haptic type \(hapticType)")
        }
    }

    func handleElementFocus(elementId: String) {
        Current.Log.verbose("Handle element focus for element ID: \(elementId)")

        // JavaScript to find and focus element in both regular DOM and Shadow DOM
        let script = """
        (function() {
            // Helper function to search through shadow DOM recursively
            function findElementInShadowDOM(elementId, root = document) {
                // Try to find by ID in current root
                let element = root.getElementById(elementId);
                if (element) return element;

                // Search through all elements with shadow roots
                const allElements = root.querySelectorAll('*');
                for (const el of allElements) {
                    if (el.shadowRoot) {
                        element = findElementInShadowDOM(elementId, el.shadowRoot);
                        if (element) return element;
                    }
                }
                return null;
            }

            // Search for the element
            const elementId = '\(elementId)';
            const element = findElementInShadowDOM(elementId);

            if (element) {
                element.focus();
            }
        })();
        """

        webViewController?.evaluateJavaScript(script) { _, error in
            if let error {
                Current.Log.error("Error focusing element \(elementId): \(error)")
            }
        }
    }

    @discardableResult
    public func sendExternalBus(message: WebSocketMessage) -> Promise<Void> {
        Promise<Void> { seal in
            DispatchQueue.main.async { [self] in
                do {
                    let encodedMsg = try JSONEncoder().encode(message)
                    let jsonString = String(decoding: encodedMsg, as: UTF8.self)
                    let script = "window.externalBus(\(jsonString))"
                    Current.Log.verbose("sending \(jsonString)")
                    webViewController?.evaluateJavaScript(script, completion: { _, error in
                        if let error {
                            Current.Log.error("failed to fire message to externalBus: \(error)")
                            seal.reject(error)
                        } else {
                            seal.fulfill(())
                        }
                    })
                } catch {
                    Current.Log.error("failed to send \(message): \(error)")
                    seal.reject(error)
                }
            }
        }
    }

    private func transferKeychainThreadCredentialsToHARequested() {
        guard let webViewController else {
            Current.Log.error("WebViewExternalMessageHandler has nil webViewController")
            return
        }

        let threadManagementView =
            UIHostingController(
                rootView: ThreadCredentialsSharingView<ThreadTransferCredentialToHAViewModel>
                    .buildTransferToHomeAssistant(server: webViewController.server)
            )
        threadManagementView.view.backgroundColor = .clear
        threadManagementView.modalPresentationStyle = .overFullScreen
        threadManagementView.modalTransitionStyle = .crossDissolve
        webViewController.presentOverlayController(controller: threadManagementView, animated: true)
    }

    private func transferHAThreadCredentialsToKeychain(macExtendedAddress: String, activeOperationalDataset: String) {
        let threadManagementView =
            UIHostingController(
                rootView: ThreadCredentialsSharingView<ThreadTransferCredentialToKeychainViewModel>
                    .buildTransferToAppleKeychain(
                        macExtendedAddress: macExtendedAddress,
                        activeOperationalDataset: activeOperationalDataset
                    )
            )
        threadManagementView.view.backgroundColor = .clear
        threadManagementView.modalPresentationStyle = .overFullScreen
        threadManagementView.modalTransitionStyle = .crossDissolve
        webViewController?.presentOverlayController(controller: threadManagementView, animated: true)
    }

    private func barcodeScannerRequested(
        title: String,
        description: String,
        alternativeOptionLabel: String?,
        incomingMessageId: Int
    ) {
        let barcodeController = BarcodeScannerHostingController(rootView: BarcodeScannerView(
            title: title,
            description: description,
            alternativeOptionLabel: alternativeOptionLabel,
            incomingMessageId: incomingMessageId
        ))
        barcodeController.modalPresentationStyle = .fullScreen
        webViewController?.presentOverlayController(controller: barcodeController, animated: true)
    }

    private func matterComissioningHandler(incomingMessage: WebSocketMessage) {
        // So we avoid conflicting credentials (or absence) between servers
        cleanPreferredThreadCredentials()
        let preferredNetWorkMacExtendedAddress = incomingMessage
            .Payload?[PayloadConstants.macExtendedAddress.rawValue] as? String
        let preferredNetWorkActiveOperationalDataset = incomingMessage
            .Payload?[PayloadConstants.activeOperationalDataset.rawValue] as? String
        let preferredNetworkExtendedPANID = incomingMessage.Payload?[PayloadConstants.extendedPanId.rawValue] as? String

        Current.Log
            .verbose(
                "Matter comission received preferredNetWorkMacExtendedAddress from frontend: \(String(describing: preferredNetWorkMacExtendedAddress))"
            )
        Current.Log
            .verbose(
                "Matter comission received preferredNetWorkActiveOperationalDataset from frontend: \(String(describing: preferredNetWorkActiveOperationalDataset))"
            )
        Current.Log
            .verbose(
                "Matter comission received preferredNetworkExtendedPANID from frontend: \(String(describing: preferredNetworkExtendedPANID))"
            )

        if let preferredNetWorkMacExtendedAddress, !preferredNetWorkMacExtendedAddress.isEmpty,
           let preferredNetWorkActiveOperationalDataset, !preferredNetWorkActiveOperationalDataset.isEmpty,
           let preferredNetworkExtendedPANID, !preferredNetworkExtendedPANID.isEmpty {
            // This information will be used in 'MatterRequestHandler'
            Current.settingsStore
                .matterLastPreferredNetWorkMacExtendedAddress = preferredNetWorkMacExtendedAddress
            Current.settingsStore
                .matterLastPreferredNetWorkActiveOperationalDataset = preferredNetWorkActiveOperationalDataset
            Current.settingsStore
                .matterLastPreferredNetWorkExtendedPANID = preferredNetworkExtendedPANID

            // Saving credential in keychain before moving forward as required, docs: https://developer.apple.com/documentation/mattersupport/matteradddeviceextensionrequesthandler/selectthreadnetwork(from:)
            Current.matter.threadClientService.saveCredential(
                macExtendedAddress: preferredNetWorkMacExtendedAddress,
                operationalDataSet: preferredNetWorkActiveOperationalDataset
            ) { [weak self] error in
                if let error {
                    Current.Log
                        .error(
                            "Error saving credentials in keychain while comissioning matter device, error: \(error.localizedDescription)"
                        )
                    let alert = UIAlertController(
                        title: L10n.Thread.SaveCredential.Fail.Alert.title(error.localizedDescription),
                        message: L10n.Thread.SaveCredential.Fail.Alert.message,
                        preferredStyle: .alert
                    )
                    alert.addAction(.init(title: L10n.cancelLabel, style: .default))
                    alert.addAction(.init(title: L10n.continueLabel, style: .destructive, handler: { [weak self] _ in
                        self?.comissionMatterDevice()
                    }))
                    self?.webViewController?.presentOverlayController(controller: alert, animated: false)
                } else {
                    Current.Log
                        .verbose(
                            "Succeeded saving thread credentials in keychain, moving forward to matter comissioning"
                        )
                    self?.comissionMatterDevice()
                }
            }
        } else {
            comissionMatterDevice()
        }
    }

    @MainActor
    private func presentBarcodeScannerMessage(message: String) {
        webViewController?.showBanner(request: .init(
            id: "BarcodeScannerMessage",
            title: nil,
            message: message,
            duration: .seconds(3),
            dimming: .none,
            style: .card(
                backgroundColor: .secondarySystemBackground,
                foregroundColor: .label
            )
        ))
    }

    @MainActor
    private func showToast(payload: ToastShowPayload) {
        if #available(iOS 18, *) {
            ToastPresenter.shared.show(
                id: payload.id,
                symbol: .infoCircleFill,
                symbolForegroundStyle: (.white, .haPrimary),
                title: payload.message,
                message: "",
                duration: payload.duration
            )
        } else {
            Current.Log.verbose("Not showing toast with id \(payload.id), Toast not available on this OS version.")
        }
    }

    @MainActor
    private func hideToast(id: String) {
        if #available(iOS 18, *) {
            ToastPresenter.shared.hide(id: id)
        } else {
            Current.Log.verbose("Not hiding toast with id \(id), Toast not available on this OS version.")
        }
    }

    private func cleanPreferredThreadCredentials() {
        Current.settingsStore.matterLastPreferredNetWorkMacExtendedAddress = nil
        Current.settingsStore.matterLastPreferredNetWorkActiveOperationalDataset = nil
        Current.settingsStore.matterLastPreferredNetWorkExtendedPANID = nil
    }

    private func comissionMatterDevice() {
        guard let webViewController else {
            Current.Log.error("WebViewController not available while commissioning matter device")
            return
        }
        Current.matter.commission(webViewController.server).done { [weak self] deviceName in
            Current.Log.info("Commission call completed with device name: \(String(describing: deviceName))")
            self?.communicateMatterCommissioningFinished(deviceName: deviceName, success: true)
        }.catch { [weak self] error in
            Current.Log.error(error)
            self?.communicateMatterCommissioningFinished(deviceName: nil, success: false)
        }
    }

    private func communicateMatterCommissioningFinished(deviceName: String?, success: Bool) {
        sendExternalBus(message: .init(
            command: WebViewExternalBusOutgoingMessage.matterCommissionFinish.rawValue,
            payload: [
                "name": deviceName as Any,
                "success": success,
            ]
        ))
    }

    func showAssist(server: Server, pipeline: String = "", autoStartRecording: Bool = false) {
        if AssistSession.shared.inProgress {
            AssistSession.shared.requestNewSession(.init(
                server: server,
                pipelineId: pipeline,
                autoStartRecording: autoStartRecording
            ))
            return
        }

        if Current.sceneManager.supportsMultipleScenes, Current.isCatalyst {
            // On macOS, open Assist in its own SwiftUI window (see `HAApp`). Its params can't be passed into
            // a plain `WindowGroup`, so configure the shared model before activating the scene.
            AssistWindowModel.shared.configure(
                server: server,
                preferredPipelineId: pipeline,
                autoStartRecording: autoStartRecording
            )
            Current.sceneManager.activateAnyScene(for: .assist)
        } else {
            // On iOS/iPad, present modally as before
            let assistView = UIHostingController(rootView: AssistView.build(
                server: server,
                preferredPipelineId: pipeline,
                autoStartRecording: autoStartRecording
            ))
            assistView.modalPresentationStyle = .fullScreen
            assistView.modalTransitionStyle = .crossDissolve
            webViewController?.presentOverlayController(controller: assistView, animated: true)
        }
    }

    func scanImprov() {
        switch Current.bluetoothPermissionStatus {
        case .denied, .restricted:
            break
        case .allowedAlways:
            improvManager.delegate = self
            improvManager.scan()
        default:
            // Mac Catalyst doesn't trigger bluetooth permission for some reason
            guard !Current.isCatalyst else { return }
            let bluetoothPermissionView = UIHostingController(rootView: BluetoothPermissionView())
            webViewController?.presentOverlayController(controller: bluetoothPermissionView, animated: true)
        }
    }

    private func presentImprov(deviceName: String?) {
        improvManager.stopScan()
        improvManager.delegate = nil

        improvController =
            UIHostingController(rootView: ImprovDiscoverView<ImprovManager>(
                improvManager: improvManager,
                deviceName: deviceName,
                redirectRequest: { [weak self] redirectUrlPath in
                    self?.webViewController?.navigateToPath(path: redirectUrlPath)
                }
            ))

        guard let improvController else { return }
        improvController.modalTransitionStyle = .crossDissolve
        improvController.modalPresentationStyle = .overFullScreen
        improvController.view.backgroundColor = .clear
        webViewController?.presentOverlayController(controller: improvController, animated: true)
    }

    func stopImprovScanIfNeeded() {
        if improvManager.scanInProgress {
            improvManager.stopScan()
        }
    }

    // MARK: - Entity Add To Handlers

    private enum EntityAddToResponseKey: String {
        case actions
    }

    private func handleGetEntityAddToActions(entityId: String, messageId: Int?) -> Guarantee<WebSocketMessage> {
        Guarantee { seal in
            entityAddToHandler.actionsForEntity(entityId: entityId).done { actions in
                do {
                    let externalActions = try actions.map { action in
                        try ExternalEntityAddToAction.from(action: action)
                    }

                    seal(WebSocketMessage(
                        id: messageId ?? -1,
                        type: "result",
                        result: [EntityAddToResponseKey.actions.rawValue: externalActions.map { $0.toDictionary() }]
                    ))
                } catch {
                    Current.Log.error("Failed to encode entity add to actions: \(error)")
                    seal(WebSocketMessage(
                        id: messageId ?? -1,
                        type: "result",
                        result: [EntityAddToResponseKey.actions.rawValue: []]
                    ))
                }
            }.catch { error in
                Current.Log.error("Failed to get entity add to actions: \(error)")
                seal(WebSocketMessage(
                    id: messageId ?? -1,
                    type: "result",
                    result: [EntityAddToResponseKey.actions.rawValue: []]
                ))
            }
        }
    }

    private func handleEntityAddTo(entityId: String, appPayload: String) {
        do {
            let action = try ExternalEntityAddToAction.toAction(from: appPayload)
            entityAddToHandler.execute(action: action, entityId: entityId).done {
                Current.Log.info("Successfully executed entity add to action for \(entityId)")
            }.catch { error in
                Current.Log.error("Failed to execute entity add to action for \(entityId): \(error)")
            }
        } catch {
            Current.Log.error("Failed to decode entity add to action: \(error)")
        }
    }

    private func showCameraPlayer(entityId: String, cameraName: String?) {
        guard let webViewController else {
            Current.Log.error("WebViewController not available while opening camera player")
            return
        }

        let view = CameraPlayerView(
            server: webViewController.server,
            cameraEntityId: entityId,
            cameraName: cameraName
        ).embeddedInHostingController()
        view.modalPresentationStyle = .overFullScreen
        webViewController.presentOverlayController(controller: view, animated: true)
    }
}

// MARK: - Acknowledged external bus commands

private final class PendingExternalBusCommand {
    let command: String
    let payload: [String: Any]?
    let retryDelay: DispatchTimeInterval
    let acknowledgementTimeout: DispatchTimeInterval
    var attemptsRemaining: Int
    /// A fresh id is assigned per attempt so a late error result for a previous attempt is ignored.
    var messageID: Int
    var acknowledgementWorkItem: DispatchWorkItem?

    init(
        command: String,
        payload: [String: Any]?,
        attemptsRemaining: Int,
        retryDelay: DispatchTimeInterval,
        acknowledgementTimeout: DispatchTimeInterval,
        messageID: Int
    ) {
        self.command = command
        self.payload = payload
        self.attemptsRemaining = attemptsRemaining
        self.retryDelay = retryDelay
        self.acknowledgementTimeout = acknowledgementTimeout
        self.messageID = messageID
    }
}

extension WebViewExternalMessageHandler {
    /// Sends a command over the external bus and keeps retrying until the frontend acknowledges it,
    /// rather than relying on a fixed delay to guess when the frontend is ready.
    ///
    /// The frontend only replies to a `command` when it could **not** handle it — the command handler
    /// isn't registered yet, or it rejected the command (see `external_messaging.ts`); a handled command
    /// produces no reply. So we retry whenever an error result is echoed back for our message id (or the
    /// JavaScript evaluation itself fails), and treat the absence of any error within
    /// `acknowledgementTimeout` as success. Main thread only.
    func sendExternalBusCommandWithRetry(command: WebViewExternalBusOutgoingMessage, payload: [String: Any]?) {
        sendExternalBusCommandWithRetry(
            command: command,
            payload: payload,
            maxAttempts: 6,
            retryDelay: .milliseconds(300),
            acknowledgementTimeout: .milliseconds(750)
        )
    }

    func sendExternalBusCommandWithRetry(
        command: WebViewExternalBusOutgoingMessage,
        payload: [String: Any]?,
        maxAttempts: Int,
        retryDelay: DispatchTimeInterval,
        acknowledgementTimeout: DispatchTimeInterval
    ) {
        // Supersede any in-flight attempt for the same command so the latest payload wins.
        cancelPendingCommands(matching: command.rawValue)

        let pending = PendingExternalBusCommand(
            command: command.rawValue,
            payload: payload,
            attemptsRemaining: maxAttempts,
            retryDelay: retryDelay,
            acknowledgementTimeout: acknowledgementTimeout,
            messageID: nextOutgoingMessageID
        )
        nextOutgoingMessageID += 1
        attemptExternalBusCommand(pending)
    }

    private func attemptExternalBusCommand(_ pending: PendingExternalBusCommand) {
        guard pending.attemptsRemaining > 0 else {
            Current.Log
                .warning("External bus command \(pending.command) not acknowledged after retries, giving up")
            pendingCommands[pending.messageID] = nil
            return
        }
        pending.attemptsRemaining -= 1
        let attemptID = pending.messageID
        pendingCommands[attemptID] = pending

        sendExternalBus(message: .init(
            id: attemptID,
            command: pending.command,
            payload: pending.payload
        )).done { [weak self, weak pending] in
            // Start the acknowledgement timer only once the command actually reached the frontend, so a
            // send failure always routes to `catch` below regardless of timing. The frontend stays
            // silent on success, so no error result within the window counts as acknowledged.
            guard let self, let pending, pendingCommands[attemptID] === pending else { return }
            let acknowledgementWorkItem = DispatchWorkItem { [weak self, weak pending] in
                guard let self, let pending, pendingCommands[attemptID] === pending else { return }
                Current.Log.verbose("External bus command \(pending.command) (id \(attemptID)) acknowledged")
                pendingCommands[attemptID] = nil
            }
            pending.acknowledgementWorkItem = acknowledgementWorkItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + pending.acknowledgementTimeout,
                execute: acknowledgementWorkItem
            )
        }.catch { [weak self, weak pending] error in
            // The frontend never saw the command, so no error result is coming — retry now.
            guard let self, let pending, pendingCommands[attemptID] === pending else { return }
            Current.Log.error("External bus command \(pending.command) failed to send: \(error)")
            retryExternalBusCommand(pending)
        }
    }

    private func retryExternalBusCommand(_ pending: PendingExternalBusCommand) {
        guard pendingCommands[pending.messageID] === pending else { return }
        pending.acknowledgementWorkItem?.cancel()
        pendingCommands[pending.messageID] = nil

        // Re-key under a fresh id and stay registered through the delay so a newer command can still
        // supersede this one; the delayed attempt bails out if that happened.
        pending.messageID = nextOutgoingMessageID
        nextOutgoingMessageID += 1
        let retryID = pending.messageID
        pendingCommands[retryID] = pending

        DispatchQueue.main.asyncAfter(deadline: .now() + pending.retryDelay) { [weak self] in
            guard let self, pendingCommands[retryID] === pending else { return }
            attemptExternalBusCommand(pending)
        }
    }

    private func cancelPendingCommands(matching command: String) {
        let ids = pendingCommands.filter { $0.value.command == command }.map(\.key)
        for id in ids {
            pendingCommands[id]?.acknowledgementWorkItem?.cancel()
            pendingCommands[id] = nil
        }
    }

    private func handleExternalBusCommandResult(_ message: WebSocketMessage) {
        guard let id = message.ID, let pending = pendingCommands[id] else { return }
        guard message.Success != true else {
            // Defensive: the frontend doesn't currently send a success ack, only failures.
            pending.acknowledgementWorkItem?.cancel()
            pendingCommands[id] = nil
            return
        }
        Current.Log.verbose("External bus command \(pending.command) (id \(id)) rejected by frontend, retrying")
        retryExternalBusCommand(pending)
    }
}

extension WebViewExternalMessageHandler: @preconcurrency ImprovManagerDelegate {
    func didUpdateBluetoohState(_ state: CBManagerState) {
        if state == .poweredOn {
            improvManager.scan()
        }
    }

    @MainActor
    func didUpdateFoundDevices(devices: [String: CBPeripheral]) {
        devices.forEach { [weak self] _, value in
            if let name = value.name {
                self?.sendExternalBus(message: .init(
                    command: WebViewExternalBusOutgoingMessage.improvDiscoveredDevice.rawValue,
                    payload: [
                        "name": name,
                    ]
                ))
            }
        }
    }
}
