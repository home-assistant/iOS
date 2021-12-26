import SharedPush
import Vapor

public extension Application {
    var legacyNotificationParser: Parser {
        .init(application: self)
    }

    struct Parser {
        let application: Application

        struct ParserKey: StorageKey {
            typealias Value = LegacyNotificationParser
        }

        public var parser: LegacyNotificationParser? {
            get {
                application.storage[ParserKey.self]
            }
            nonmutating set {
                self.application.storage[ParserKey.self] = newValue
            }
        }
    }
}

extension Application.Parser: LegacyNotificationParser {
    public func result(
        from input: [String: Any],
        defaultRegistrationInfo: @autoclosure () -> [String: String]
    ) -> LegacyNotificationParserResult {
        if let parser = parser {
            return parser.result(from: input, defaultRegistrationInfo: defaultRegistrationInfo())
        } else {
            fatalError("parser not configured")
        }
    }
}
