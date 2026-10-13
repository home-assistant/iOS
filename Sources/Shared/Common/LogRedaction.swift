import Foundation

public enum LogRedaction {
    public static let placeholder = "<redacted>"
    static let externalURLPlaceholder = "<external URL>"
    static let remoteUIURLPlaceholder = "<remote UI URL>"

    #if DEBUG
    public static let isEnabled = false
    #else
    public static let isEnabled = true
    #endif

    static let sensitiveKeys: Set<String> = [
        "access_token",
        "cloudhook_url",
        "push_token",
        "refresh_token",
        "remote_ui_url",
        "secret",
        "start_live_activity_token",
        "webhook_id",
        "widgetAuthenticity",
    ]

    private struct Rule {
        let expression: NSRegularExpression
        let template: String
        let anchors: [[UInt8]]

        init?(pattern: String, template: String, anchors: [String]) {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
            self.expression = expression
            self.template = template
            self.anchors = anchors.map { Array($0.utf8) }.filter { !$0.isEmpty }
        }
    }

    private final class Matcher {
        let rules: [Rule]
        private let isFirstByte: [Bool]
        private let buckets: [[(anchor: [UInt8], rule: Int)]]

        init(rules: [Rule]) {
            var buckets = Array(repeating: [(anchor: [UInt8], rule: Int)](), count: 256)
            for (index, rule) in rules.prefix(64).enumerated() {
                for anchor in rule.anchors {
                    buckets[Int(anchor[0])].append((anchor, index))
                }
            }
            self.rules = Array(rules.prefix(64))
            self.buckets = buckets
            self.isFirstByte = buckets.map { !$0.isEmpty }
        }

        func applicableRules(in bytes: UnsafeBufferPointer<UInt8>) -> [Rule] {
            guard let base = bytes.baseAddress else { return [] }
            let count = bytes.count
            var found: UInt64 = 0
            isFirstByte.withUnsafeBufferPointer { isFirstByte in
                for position in 0 ..< count where isFirstByte[Int(base[position])] {
                    for (anchor, rule) in buckets[Int(base[position])]
                        where found & (1 << rule) == 0 && anchor.count <= count - position {
                        let isMatch = anchor.withUnsafeBufferPointer {
                            memcmp(base + position, $0.baseAddress!, $0.count) == 0
                        }
                        if isMatch {
                            found |= 1 << rule
                        }
                    }
                }
            }
            guard found != 0 else { return [] }
            return rules.indices.filter { found & (1 << $0) != 0 }.map { rules[$0] }
        }
    }

    private static let builtInRules: [Rule] = {
        let keys = sensitiveKeys.sorted()
        let value = #"(?:\\/|[^"\\\s,;\]\)\}&])+"#
        let keyPattern = keys.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let secret = "$1\(placeholder)"
        return [
            Rule(pattern: #"(\bBearer\s+)[^\s"'\\,;]+"#, template: secret, anchors: ["Bearer"]),
            Rule(
                pattern: #"(\b(?:"# + keyPattern + #")\b\\?"?\)?\s*[:=]\s*\\?"?)"# + value,
                template: secret,
                anchors: keys
            ),
            Rule(
                pattern: #"(hooks\.nabu\.casa\\?/)[A-Za-z0-9_=\-]+"#,
                template: secret,
                anchors: ["hooks.nabu.casa"]
            ),
            Rule(
                pattern: #"(api\\?/webhook\\?/)[A-Za-z0-9_\-]+"#,
                template: secret,
                anchors: ["webhook/", #"webhook\/"#]
            ),
            Rule(pattern: #"(APNS token: )[0-9a-fA-F]+"#, template: secret, anchors: ["APNS token: "]),
            Rule(
                pattern: #"(?<![A-Za-z0-9.\-])[A-Za-z0-9\-]+\.ui\.nabu\.casa\b"#,
                template: remoteUIURLPlaceholder,
                anchors: [".ui.nabu.casa"]
            ),
        ].compactMap { $0 }
    }()

    private static let matcherLock = NSLock()
    private static var matcher = Matcher(rules: builtInRules)

    public static func redact(_ text: String) -> String {
        isEnabled ? scrub(text) : text
    }

    public static func redact(_ url: URL) -> String {
        redact(url.absoluteString)
    }

    public static func redactToken(_ token: String) -> String {
        isEnabled ? maskToken(token) : token
    }

    public static func redactValues(in value: Any) -> Any {
        isEnabled ? scrubValues(in: value) : value
    }

    static func updateExternalHosts(_ hosts: [String]) {
        let hosts = Set(hosts.filter { !$0.isEmpty }).sorted { $0.count > $1.count }
        let hostsRule = hosts.isEmpty ? nil : Rule(
            pattern: #"(?<![A-Za-z0-9.\-])(?:"# +
                hosts.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") +
                #")(?![A-Za-z0-9\-])"#,
            template: externalURLPlaceholder,
            anchors: hosts
        )
        let updated = Matcher(rules: builtInRules + [hostsRule].compactMap { $0 })

        matcherLock.lock()
        matcher = updated
        matcherLock.unlock()
    }

    static func scrub(_ text: String) -> String {
        matcherLock.lock()
        let matcher = matcher
        matcherLock.unlock()

        var text = text
        let applicable = text.withUTF8 { matcher.applicableRules(in: $0) }
        guard !applicable.isEmpty else { return text }

        let result = NSMutableString(string: text)
        for rule in applicable {
            rule.expression.replaceMatches(
                in: result,
                range: NSRange(location: 0, length: result.length),
                withTemplate: rule.template
            )
        }
        return result as String
    }

    static func maskToken(_ token: String) -> String {
        "<redacted, ends \(token.suffix(4))>"
    }

    static func scrubValues(in value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            return dictionary.reduce(into: [String: Any]()) { result, element in
                result[element.key] = sensitiveKeys.contains(element.key)
                    ? placeholder
                    : scrubValues(in: element.value)
            }
        case let dictionary as [AnyHashable: Any]:
            return dictionary.reduce(into: [AnyHashable: Any]()) { result, element in
                let isSensitive = (element.key.base as? String).map(sensitiveKeys.contains) ?? false
                result[element.key] = isSensitive ? placeholder : scrubValues(in: element.value)
            }
        case let array as [Any]:
            return array.map(scrubValues(in:))
        case let string as String:
            return scrub(string)
        default:
            return value
        }
    }
}
