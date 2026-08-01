import Foundation

public struct AdditionalRequestHeader: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var value: String

    public init(id: UUID = UUID(), name: String, value: String) {
        self.id = id
        self.name = name
        self.value = value
    }

    public var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var normalizedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        Self.isAllowedName(normalizedName) &&
            !normalizedValue.isEmpty &&
            normalizedValue.rangeOfCharacter(from: .newlines) == nil
    }

    public static func sanitizedHeaders(from headers: [AdditionalRequestHeader]) -> [(name: String, value: String)] {
        var seenHeaderNames = Set<String>()
        return headers.compactMap { header in
            guard header.isValid else { return nil }

            let lowercasedName = header.normalizedName.lowercased()
            guard seenHeaderNames.insert(lowercasedName).inserted else { return nil }

            return (name: header.normalizedName, value: header.normalizedValue)
        }
    }

    public static func isAllowedName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }

        guard name.unicodeScalars.allSatisfy({ allowedHeaderNameScalars.contains($0) }) else {
            return false
        }

        return !reservedHeaderNames.contains(name.lowercased())
    }

    private static let allowedHeaderNameScalars = Set(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+-.^_`|~".unicodeScalars
    )

    private static let reservedHeaderNames: Set<String> = [
        "accept",
        "accept-encoding",
        "authorization",
        "connection",
        "content-length",
        "content-type",
        "cookie",
        "host",
        "keep-alive",
        "origin",
        "proxy-authenticate",
        "proxy-authorization",
        "referer",
        "set-cookie",
        "te",
        "trailer",
        "transfer-encoding",
        "upgrade",
        "user-agent",
    ]
}
