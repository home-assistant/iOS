import Foundation
import UIKit

public struct NotificationSenderInfo: Equatable {
    public enum Source: Equatable {
        case iconURL(URL, needsAuth: Bool)

        case mdi(
            name: String,
            background: UIColor,
            foreground: UIColor,
            colorString: String?,
            iconColorString: String?
        )

        public static func == (lhs: Source, rhs: Source) -> Bool {
            switch (lhs, rhs) {
            case let (.iconURL(lhsURL, lhsNeedsAuth), .iconURL(rhsURL, rhsNeedsAuth)):
                return lhsURL == rhsURL && lhsNeedsAuth == rhsNeedsAuth
            case let (
                .mdi(lhsName, lhsBg, lhsFg, lhsColStr, lhsIconColStr),
                .mdi(rhsName, rhsBg, rhsFg, rhsColStr, rhsIconColStr)
            ):
                if lhsName != rhsName { return false }
                let bgEqual = (lhsColStr != nil && rhsColStr != nil) ? (lhsColStr == rhsColStr) : lhsBg.isEqual(rhsBg)
                let fgEqual = (lhsIconColStr != nil && rhsIconColStr != nil) ? (lhsIconColStr == rhsIconColStr) : lhsFg
                    .isEqual(rhsFg)
                return bgEqual && fgEqual
            default:
                return false
            }
        }
    }

    public let source: Source
    public let senderName: String

    public init(source: Source, senderName: String) {
        self.source = source
        self.senderName = senderName
    }
}
