import Foundation
import PromiseKit

public enum TagManagerHandleResult {
    public enum HandledType {
        case nfc
        case generic
    }

    case unhandled
    case handled(HandledType)
    case requiresApproval(tag: String, type: HandledType)
    case open(URL)
}

public enum TagManagerError: LocalizedError {
    case nfcUnavailable
    case notHomeAssistantTag
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .nfcUnavailable: return L10n.Nfc.notAvailable
        case .notHomeAssistantTag: return L10n.Nfc.Read.Error.notHomeAssistant
        case .invalidURL: return L10n.Nfc.Write.Error.invalidUrl
        }
    }
}

public protocol TagManager {
    var isNFCAvailable: Bool { get }
    func readNFC() -> Promise<String>
    func writeNFC(value: String) -> Promise<String>
    /// Writes a deep link to a tag, instead of a Home Assistant tag identifier, so that scanning the tag
    /// opens the link in the app rather than firing a tag event. The deep link travels wrapped in the
    /// app's NFC universal link, since that is the only form an iPhone routes back to the app on a scan.
    /// - Parameters:
    ///   - deeplink: The deep link a scan of the tag should open.
    ///   - alertMessage: What the system NFC sheet tells the user to do while it waits for a tag.
    func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void>
    func handle(userActivity: NSUserActivity) -> TagManagerHandleResult
    func fireEvent(tag: String) -> Promise<Void>
}

public extension TagManager {
    func writeRandomNFC() -> Promise<String> {
        let value = UUID().uuidString.lowercased()
        return writeNFC(value: value)
    }

    func fireEvent(tag: String) -> Promise<Void> {
        when(fulfilled: Current.apis.map { api -> Promise<Void> in
            if api.server.info.version < .tagWebhookAvailable {
                let event = api.tagEvent(tagPath: tag)
                return api.CreateEvent(eventType: event.eventType, eventData: event.eventData)
            } else {
                return Current.webhooks.send(server: api.server, request: .init(type: "scan_tag", data: [
                    "tag_id": tag,
                ]))
            }
        })
    }
}

class EmptyTagManager: TagManager {
    var isNFCAvailable: Bool {
        false
    }

    func readNFC() -> Promise<String> {
        .init(error: TagManagerError.nfcUnavailable)
    }

    func writeNFC(value: String) -> Promise<String> {
        .init(error: TagManagerError.nfcUnavailable)
    }

    func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void> {
        .init(error: TagManagerError.nfcUnavailable)
    }

    func handle(userActivity: NSUserActivity) -> TagManagerHandleResult {
        .unhandled
    }
}
