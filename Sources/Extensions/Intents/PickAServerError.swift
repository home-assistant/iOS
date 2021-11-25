import Foundation

enum PickAServerError {
    // NSError because LocalizedError doesn't send messages through
    static var error: NSError {
        .init(domain: "HAShortcuts", code: -1, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Select a server before picking this value.", comment: "")
        ])
    }
}
