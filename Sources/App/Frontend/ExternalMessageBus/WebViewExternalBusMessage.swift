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
    case frontendLoaded = "frontend/loaded"
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
    case assistSettings = "assist/settings"
    case scanForImprov = "improv/scan"
    case improvConfigureDevice = "improv/configure_device"
    case focusElement = "focus_element"
    case toastShow = "toast/show"
    case toastHide = "toast/hide"
    case entityAddToGetActions = "entity/add_to/get_actions"
    case entityAddTo = "entity/add_to"
    case cameraPlayerShow = "camera/show"
    case frontendReloadAndClearCache = "frontend/reload_and_clear_cache"
    case sidebarShow = "sidebar/show"
    case moreInfoOpened = "more_info/opened"
    case moreInfoClosed = "more_info/closed"
    /// Asks for a frontend route in a modal of the app's own, while it reports `hasNativeModal`.
    case modalOpen = "modal/open"
    /// Sent from inside a native modal when its close button is tapped.
    case modalClose = "modal/close"
    /// Sent from inside a native modal instead of navigating to another page itself.
    case modalNavigate = "modal/navigate"
    /// What changed about a modal already up: the header to draw, the room the page needs.
    case modalUpdate = "modal/update"
    case entityControlled = "entity/controlled"

    @MainActor static var configResult: [String: Any] {
        [
            "hasSettingsScreen": !Current.isCatalyst,
            "hasSidebar": AppLabsFeature.macNativeSidebar.isEnabled || AppLabsFeature.iosNativeTabBar.isEnabled,
            "canWriteTag": Current.tags.isNFCAvailable,
            "canCommissionMatter": Current.matter.isAvailable,
            "hasMatterStatusReport": Current.matter.isAvailable,
            "canImportThreadCredentials": Current.matter.threadCredentialsSharingEnabled,
            "hasBarCodeScanner": true,
            "canTransferThreadCredentialsToKeychain": Current.matter
                .threadCredentialsStoreInKeychainEnabled,
            "hasAssist": true,
            "hasAssistSettings": true,
            "hasCameraPlayer": !Current.isCatalyst,
            "canSetupImprov": true,
            "downloadFileSupported": true,
            "hasEntityAddTo": true,
            // Native modals are iOS 26 and later, and never Catalyst: the bar is built on that
            // release's navigation subtitle and close button role, and a Mac window has no sheet to
            // present in.
            "hasNativeModal": AppLabsFeature.nativeMoreInfo.isEnabled,
            "hasSplashscreen": true,
            "appVersion": "\(AppConstants.version) (\(AppConstants.build))",
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
    case matterCommissionFinish = "matter/commission/finish"
    case kioskModeSet = "kiosk_mode/set"
    case showNotifications = "notifications/show"
    /// A tap on a native modal's header; the payload's `id` is from `modal/update`.
    case modalAction = "modal/action"
}
