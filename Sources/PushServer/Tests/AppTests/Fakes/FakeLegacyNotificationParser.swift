import SharedPush

class FakeLegacyNotificationParser: LegacyNotificationParser {
    var resultHandler: (_ input: [String: Any]) -> LegacyNotificationParserResult = { _ in
        .init(headers: [:], payload: [:])
    }

    func result(
        from input: [String: Any],
        defaultRegistrationInfo: @autoclosure () -> [String: String]
    ) -> LegacyNotificationParserResult {
        resultHandler(input)
    }
}
