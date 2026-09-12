import Foundation
import PromiseKit
import Shared

/// Test double for `TagManager`, recording what the app asks it to write to an NFC tag.
final class MockTagManager: TagManager {
    var isNFCAvailable = true
    var writeDeeplinkResult: Promise<Void> = .value(())

    private(set) var writtenValues: [String] = []
    private(set) var writtenDeeplinks: [URL] = []
    private(set) var writeDeeplinkAlertMessages: [String] = []

    func readNFC() -> Promise<String> {
        .value("mock-tag")
    }

    func writeNFC(value: String) -> Promise<String> {
        writtenValues.append(value)
        return .value(value)
    }

    func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void> {
        writtenDeeplinks.append(deeplink)
        writeDeeplinkAlertMessages.append(alertMessage)
        return writeDeeplinkResult
    }

    func handle(userActivity: NSUserActivity) -> TagManagerHandleResult {
        .unhandled
    }

    func fireEvent(tag: String) -> Promise<Void> {
        .value(())
    }
}
