import CoreBluetooth
import Foundation
import Improv_iOS
import PromiseKit
import Shared
import SwiftUI

final class WebViewExternalMessageHandler {
    weak var webViewController: WebViewControllerProtocol?
    private let improvManager: any ImprovManagerProtocol
    private let localNotificationDispatcher: LocalNotificationDispatcherProtocol

    private var improvController: UIViewController?

    init(
        improvManager: any ImprovManagerProtocol,
        localNotificationDispatcher: LocalNotificationDispatcherProtocol
    ) {
        self.improvManager = improvManager
        self.localNotificationDispatcher = localNotificationDispatcher
    }

    func handleExternalMessage(_ dictionary: [String: Any]) {
        guard let webViewController else {
            Current.Log.error("WebViewExternalMessageHandler has nil webViewController")
            return
        }
        guard let incomingMessage = WebSocketMessage(dictionary) else {
            Current.Log.error("Received invalid external message \(dictionary)")
            return
        }

        var response: Guarantee<WebSocketMessage>?

        if let externalBusMessage = WebViewExternalBusMessage(rawValue: incomingMessage.MessageType) {
            switch externalBusMessage {
            case .configGet:
                response = Guarantee { seal in
                    DispatchQueue.global(qos: .userInitiated).async {
                        seal(WebSocketMessage(
                            id: incomingMessage.ID!,
                            type: "result",
                            result: [
                                "hasSettingsScreen": !Current.isCatalyst,
                                "canWriteTag": Current.tags.isNFCAvailable,
                                "canCommissionMatter": Current.matter.isAvailable,
                                "canImportThreadCredentials": Current.matter.threadCredentialsSharingEnabled,
                                "hasBarCodeScanner": true,
                                "canTransferThreadCredentialsToKeychain": Current.matter
                                    .threadCredentialsStoreInKeychainEnabled,
                                "hasAssist": true,
                                "canSetupImprov": true,
                            ]
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
                webViewController.updateSettingsButton(state: connEvt)
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
                Current.matter.commission(webViewController.server).done {
                    Current.Log.info("commission call completed")
                }.catch { error in
                    // we don't show a user-visible error because even a successful operation will return 'cancelled'
                    // but the errors aren't public, so we can't compare -- the apple ui shows errors visually though
                    Current.Log.error(error)
                }
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
                if webViewController.overlayAppController as? BarcodeScannerHostingController != nil {
                    webViewController.dismissControllerAboveOverlayController()
                    webViewController.dismissOverlayController(animated: true, completion: nil)
                }
            case .barCodeScannerNotify:
                guard let message = incomingMessage.Payload?["message"] as? String else { return }
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(.init(title: L10n.okLabel, style: .default))
                webViewController.presentController(alert, animated: false)
            case .threadStoreCredentialInAppleKeychain:
                guard let macExtendedAddress = incomingMessage.Payload?["mac_extended_address"] as? String,
                      let activeOperationalDataset = incomingMessage.Payload?["active_operational_dataset"] as? String else { return }
                transferHAThreadCredentialsToKeychain(
                    macExtendedAddress: macExtendedAddress,
                    activeOperationalDataset: activeOperationalDataset
                )
            case .assistShow:
                showAssist(server: webViewController.server, pipeline: "")
            case .scanForImprov:
                scanImprov()
            }
        } else {
            Current.Log.error("unknown: \(incomingMessage.MessageType)")
        }

        response?.then { [self] outgoing in
            sendExternalBus(message: outgoing)
        }.cauterize()
    }

    func showSettingsViewController() {
        if Current.sceneManager.supportsMultipleScenes, Current.isCatalyst {
            Current.sceneManager.activateAnyScene(for: .settings)
        } else {
            let settingsView = SettingsViewController()
            settingsView.hidesBottomBarWhenPushed = true
            let navController = UINavigationController(rootViewController: settingsView)
            webViewController?.presentOverlayController(controller: navController)
        }
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
                        }
                        seal.resolve(error)
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

        if #available(iOS 16.4, *) {
            let threadManagementView =
                UIHostingController(
                    rootView: ThreadCredentialsSharingView<ThreadTransferCredentialToHAViewModel>
                        .buildTransferToHomeAssistant(server: webViewController.server)
                )
            threadManagementView.view.backgroundColor = .clear
            threadManagementView.modalPresentationStyle = .overFullScreen
            threadManagementView.modalTransitionStyle = .crossDissolve
            webViewController.presentController(threadManagementView, animated: true)
        }
    }

    private func transferHAThreadCredentialsToKeychain(macExtendedAddress: String, activeOperationalDataset: String) {
        if #available(iOS 16.4, *) {
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
            webViewController?.presentController(threadManagementView, animated: true)
        }
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
        webViewController?.presentOverlayController(controller: barcodeController)
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
        let assistView = UIHostingController(rootView: AssistView.build(
            server: server,
            preferredPipelineId: pipeline,
            autoStartRecording: autoStartRecording
        ))

        webViewController?.presentOverlayController(controller: assistView)
    }

    func scanImprov() {
        improvManager.delegate = self
        improvManager.scan()
    }

    func presentImprov() {
        improvManager.stopScan()
        improvManager.delegate = nil

        improvController =
            UIHostingController(rootView: ImprovDiscoverView<ImprovManager>(
                improvManager: improvManager,
                redirectRequest: { [weak self] redirectUrlPath in
                    self?.webViewController?.navigateToPath(path: redirectUrlPath)
                }
            ))

        guard let improvController else { return }
        improvController.modalTransitionStyle = .crossDissolve
        improvController.modalPresentationStyle = .overFullScreen
        improvController.view.backgroundColor = .clear
        webViewController?.presentOverlayController(controller: improvController)
    }

    func stopImprovScanIfNeeded() {
        if improvManager.scanInProgress {
            improvManager.stopScan()
        }
    }
}

extension WebViewExternalMessageHandler: ImprovManagerDelegate {
    func didUpdateBluetoohState(_ state: CBManagerState) {
        if state == .poweredOn {
            improvManager.scan()
        }
    }

    func didUpdateFoundDevices(devices: [String: CBPeripheral]) {
        if !devices.isEmpty {
            localNotificationDispatcher.send(.init(
                id: .improvSetup,
                title: L10n.Improv.Toast.title
            ))
        }
    }
}
