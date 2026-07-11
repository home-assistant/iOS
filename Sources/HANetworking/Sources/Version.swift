import Foundation

public struct Version: Equatable, Comparable, Hashable, Codable, CustomStringConvertible {
    public var major: Int
    public var minor: Int?
    public var patch: Int?
    public var prerelease: String?
    public var build: String?

    private var canonicalMinor: Int { minor ?? 0 }
    private var canonicalPatch: Int { patch ?? 0 }

    public init(
        major: Int = 0,
        minor: Int? = nil,
        patch: Int? = nil,
        prerelease: String? = nil,
        build: String? = nil
    ) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.build = build
    }

    public init(_ string: String, strict: Bool = false) throws {
        self = try VersionParser(strict: strict).parse(string: string)
    }

    public static func == (lhs: Version, rhs: Version) -> Bool {
        lhs.major == rhs.major
            && lhs.canonicalMinor == rhs.canonicalMinor
            && lhs.canonicalPatch == rhs.canonicalPatch
            && lhs.prerelease == rhs.prerelease
    }

    public static func === (lhs: Version, rhs: Version) -> Bool {
        lhs == rhs && lhs.build == rhs.build
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.canonicalMinor != rhs.canonicalMinor {
            return lhs.canonicalMinor < rhs.canonicalMinor
        }
        if lhs.canonicalPatch != rhs.canonicalPatch {
            return lhs.canonicalPatch < rhs.canonicalPatch
        }
        switch (lhs.prerelease, rhs.prerelease) {
        case (.some, .none):
            return true
        case (.none, .some), (.none, .none):
            return false
        case let (.some(lprerelease), .some(rprerelease)):
            return Self.compareNumeric(lprerelease, rprerelease) == .orderedAscending
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(major)
        hasher.combine(canonicalMinor)
        hasher.combine(canonicalPatch)
        hasher.combine(prerelease)
    }

    public var description: String {
        var result = "\(major)"
        if let minor {
            result += ".\(minor)"
        }
        if let patch {
            result += ".\(patch)"
        }
        if let prerelease {
            result += "-\(prerelease)"
        }
        if let build {
            result += "+\(build)"
        }
        return result
    }

    private static func compareNumeric(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsComponents = lhs.components(separatedBy: ".")
        let rhsComponents = rhs.components(separatedBy: ".")
        for (left, right) in zip(lhsComponents, rhsComponents) where left != right {
            if let leftNumber = Int(left), let rightNumber = Int(right) {
                return leftNumber < rightNumber ? .orderedAscending : .orderedDescending
            }
            return left < right ? .orderedAscending : .orderedDescending
        }
        if lhsComponents.count != rhsComponents.count {
            return lhsComponents.count < rhsComponents.count ? .orderedAscending : .orderedDescending
        }
        return .orderedSame
    }
}

extension Version: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        guard let version = try? VersionParser(strict: false).parse(string: value) else {
            preconditionFailure("Invalid Version string literal: \(value)")
        }
        self = version
    }
}

public struct VersionParser {
    enum ParserError: Error {
        case missingMinorComponent
        case missingPatchComponent
        case invalidComponents
        case invalidMajorComponent
        case invalidMinorComponent
        case invalidPatchComponent
    }

    private let strict: Bool
    private let versionRegex: NSRegularExpression

    public init(strict: Bool = true) {
        self.strict = strict
        self.versionRegex = Self.makeVersionRegex(strict: strict)
    }

    public func parse(string: String) throws -> Version {
        try parse(components: groups(of: string))
    }

    public func parse(components: [String?]) throws -> Version {
        guard components.count == 6 else {
            throw ParserError.invalidComponents
        }

        if strict {
            if components[2] == nil {
                throw ParserError.missingMinorComponent
            } else if components[3] == nil {
                throw ParserError.missingPatchComponent
            }
        }

        guard let major = components[1].flatMap({ Int($0) }) else {
            throw ParserError.invalidMajorComponent
        }

        var version = Version(major: major)

        if let minor = components[2].flatMap({ Int($0) }) {
            version.minor = minor
        } else if components[2] != nil {
            throw ParserError.invalidMinorComponent
        }

        if let patch = components[3].flatMap({ Int($0) }) {
            version.patch = patch
        } else if components[3] != nil {
            throw ParserError.invalidPatchComponent
        }

        version.prerelease = components[4]
        version.build = components[5]

        return version
    }

    private func groups(of string: String) -> [String?] {
        let range = NSRange(string.startIndex..., in: string)
        guard let match = versionRegex.firstMatch(in: string, range: range) else {
            return []
        }
        return (0 ..< match.numberOfRanges).map { index in
            let matchRange = match.range(at: index)
            guard matchRange.location != NSNotFound, let stringRange = Range(matchRange, in: string) else {
                return nil
            }
            return String(string[stringRange])
        }
    }

    private static func makeVersionRegex(strict: Bool) -> NSRegularExpression {
        let number = strict ? "0|[1-9][0-9]*" : "[0-9]+"
        let version: String
        if strict {
            version = "(\(number))\\.(\(number))\\.(\(number))"
        } else {
            version = "(\(number))(?:\\.(\(number)))?(?:\\.(\(number)))?"
        }
        let prerelease = "(?:-([0-9A-Za-z-.]+))?(?:\\+([0-9A-Za-z-]+))?"
        let pattern = "\\A\(version + prerelease)?\\z"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            preconditionFailure("Invalid version regex pattern: \(pattern)")
        }
        return regex
    }
}
