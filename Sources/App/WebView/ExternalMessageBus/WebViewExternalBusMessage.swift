import Foundation
import Shared

/// External Bus message types used by the web view integration.
/// - See: Home Assistant External Bus docs: https://developers.home-assistant.io/docs/frontend/external-bus
/// - See: Frontend implementation:
/// https://github.com/home-assistant/frontend/blob/dev/src/external_app/external_messaging.ts
enum WebViewExternalBusMessage: String, CaseIterable {
    case configGet = "config/get"
    case configScreenShow = "config_screen/show"
    case haptic
    case connectionStatus = "connection-status"
    case tagRead = "tag/read"
    case tagWrite = "tag/write"
    case themeUpdate = "theme-update"
    case matterCommission = "matter/commission"
    case threadImportCredentials = "thread/import_credentials"
    case threadStoreCredentialInAppleKeychain = "thread/store_in_platform_keychain"
    case barCodeScanner = "bar_code/scan"
    case barCodeScannerClose = "bar_code/close"
    case barCodeScannerNotify = "bar_code/notify"
    case assistShow = "assist/show"
    case scanForImprov = "improv/scan"
    case improvConfigureDevice = "improv/configure_device"
    case focusElement = "focus_element"
    case toastShow = "toast/show"
    case toastHide = "toast/hide"

    @MainActor static var configResult: [String: Any] {
        [
            "hasSettingsScreen": !Current.isCatalyst,
            "canWriteTag": Current.tags.isNFCAvailable,
            "canCommissionMatter": Current.matter.isAvailable,
            "canImportThreadCredentials": Current.matter.threadCredentialsSharingEnabled,
            "hasBarCodeScanner": true,
            "canTransferThreadCredentialsToKeychain": Current.matter
                .threadCredentialsStoreInKeychainEnabled,
            "hasAssist": true,
            "canSetupImprov": true,
            "downloadFileSupported": true,
            "appVersion": "\(AppConstants.version) (\(AppConstants.build))",
            "toastComponentVersion": { // Frontend can use this to know if the version has what it needs
                if #available(iOS 18, *), !Current.isCatalyst, Current.settingsStore.toastsHandledByApp {
                    return ToastManager.toastComponentVersion
                } else {
                    return -1
                }
            }(),
        ]
    }
}

enum WebViewExternalBusOutgoingMessage: String, CaseIterable {
    case showSidebar = "sidebar/show"
    case showAutomationEditor = "automation/editor/show"
    case barCodeScanResult = "bar_code/scan_result"
    case barCodeScanAborted = "bar_code/aborted"
    case improvDiscoveredDevice = "improv/discovered_device"
    case improvDiscoveredDeviceSetupDone = "improv/device_setup_done"
    case navigate = "navigate"
}
