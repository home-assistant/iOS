import Foundation
import XCGLogger

final class LogRedactionFormatter: LogFormatterProtocol {
    @discardableResult
    func format(logDetails: inout LogDetails, message: inout String) -> String {
        message = LogRedaction.scrub(message)
        return message
    }

    var debugDescription: String {
        "LogRedactionFormatter"
    }
}
