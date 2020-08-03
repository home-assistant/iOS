import Foundation
import PromiseKit

public enum NFCManagerHandleResult {
    case unhandled
    case handled
    case open(URL)
}

public enum NFCManagerError: LocalizedError {
    case unavailable
    case notHomeAssistantTag

    public var errorDescription: String? {
        switch self {
        case .unavailable: return L10n.Nfc.notAvailable
        case .notHomeAssistantTag: return L10n.Nfc.Read.Error.notHomeAssistant
        }
    }
}

public protocol NFCManager {
    var isAvailable: Bool { get }
    func read() -> Promise<String>
    func write(value: String) -> Promise<String>
    func handle(userActivity: NSUserActivity) -> NFCManagerHandleResult
    func fireEvent(tag: String) -> Promise<Void>
}

public extension NFCManager {
    func writeRandom() -> Promise<String> {
        let value = UUID().uuidString.lowercased()
        return write(value: value)
    }

    func fireEvent(tag: String) -> Promise<Void> {
        return firstly { () -> Promise<HomeAssistantAPI> in
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api -> Promise<Void> in
            let event = HomeAssistantAPI.nfcTagEvent(tagPath: tag)
            return api.CreateEvent(eventType: event.eventType, eventData: event.eventData)
        }
    }
}

class EmptyNFCManager: NFCManager {
    var isAvailable: Bool {
        false
    }

    func read() -> Promise<String> {
        return .init(error: NFCManagerError.unavailable)
    }

    func write(value: String) -> Promise<String> {
        return .init(error: NFCManagerError.unavailable)
    }

    func handle(userActivity: NSUserActivity) -> NFCManagerHandleResult {
        return .unhandled
    }
}
