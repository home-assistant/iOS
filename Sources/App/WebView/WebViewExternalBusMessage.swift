import Foundation

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
    case qrCodeScanner = "qr_code/scan"
}
