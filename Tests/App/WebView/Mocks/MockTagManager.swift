import Foundation
import PromiseKit
import Shared

/// Test double for `TagManager`, recording what the app asks it to write to an NFC tag.
final class MockTagManager: TagManager {
    var isNFCAvailable = true
    var writeURLResult: Promise<Void> = .value(())

    private(set) var writtenValues: [String] = []
    private(set) var writtenURLs: [URL] = []
    private(set) var writeURLAlertMessages: [String] = []

    func readNFC() -> Promise<String> {
        .value("mock-tag")
    }

    func writeNFC(value: String) -> Promise<String> {
        writtenValues.append(value)
        return .value(value)
    }

    func writeNFC(url: URL, alertMessage: String) -> Promise<Void> {
        writtenURLs.append(url)
        writeURLAlertMessages.append(alertMessage)
        return writeURLResult
    }

    func handle(userActivity: NSUserActivity) -> TagManagerHandleResult {
        .unhandled
    }

    func fireEvent(tag: String) -> Promise<Void> {
        .value(())
    }
}
