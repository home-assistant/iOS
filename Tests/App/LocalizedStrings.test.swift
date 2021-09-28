import Foundation
@testable import HomeAssistant
@testable import Shared
import XCTest

class LocalizedStrings: XCTestCase {
    func testLanguages() throws {
        let expressions: [NSRegularExpression] = [
            try NSRegularExpression(pattern: "%{1,2}[+0123456789$.luq]*?[sduiefgcCp@]", options: []),
            try NSRegularExpression(pattern: "\\$\\{[^}]+\\}", options: []),
        ]

        for bundle in [
            Bundle(for: AppDelegate.self),
            Bundle(for: AppEnvironment.self),
        ] {
            for languageSet in try Self.languageSets(for: bundle) {
                try validate(languageSet: languageSet, expressions: expressions)
            }
        }
    }

    struct LanguageWithStrings {
        let file: URL
        let strings: [String: String]

        init(url: URL) throws {
            self.file = url
            self.strings = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        }
    }

    struct LanguageSet {
        let name: String
        let english: LanguageWithStrings
        let other: [String: LanguageWithStrings]
    }

    private static func languageSets(for bundle: Bundle) throws -> [LanguageSet] {
        var languages = [String]()
        var stringsFiles = [String]()

        for case let url as URL in try XCTUnwrap(FileManager.default.enumerator(
            at: try XCTUnwrap(bundle.resourceURL),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsSubdirectoryDescendants]
        )) {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = try XCTUnwrap(values.isDirectory)

            guard isDirectory, url.pathExtension == "lproj" else {
                continue
            }

            let language = url.deletingPathExtension().lastPathComponent

            if language == "en" {
                for case let subURL as URL in try XCTUnwrap(FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: []
                )) where subURL.pathExtension == "strings" {
                    stringsFiles.append(subURL.deletingPathExtension().lastPathComponent)
                }
            } else if language != "Base" {
                languages.append(language)
            }
        }

        return try stringsFiles.map { strings in
            func value(for language: String) throws -> LanguageWithStrings {
                try .init(url: try XCTUnwrap(bundle.url(
                    forResource: strings,
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: language
                )))
            }

            return LanguageSet(
                name: strings,
                english: try value(for: "en"),
                other: Dictionary(uniqueKeysWithValues: try languages.map { language in
                    (key: language, value: try value(for: language))
                })
            )
        }
    }

    struct MatchSet: Equatable, CustomStringConvertible {
        let countedSet: NSCountedSet

        var description: String {
            guard countedSet.count > 0 else {
                return "<no matches>"
            }

            return countedSet.map { value in
                let count = countedSet.count(for: value)
                if count == 1 {
                    return String(describing: value)
                } else {
                    return String(format: "%@ (%d)", String(describing: value), count)
                }
            }.joined(separator: ", ")
        }
    }

    private func matchSet(for expressions: [NSRegularExpression], in string: String) -> MatchSet {
        let matches = expressions.flatMap { expression in
            expression.matches(
                in: string,
                options: [],
                range: NSRange(location: 0, length: string.utf16.count)
            )
        }

        return MatchSet(countedSet: NSCountedSet(array: matches.map { result in
            (string as NSString).substring(with: result.range)
        }))
    }

    private func validate(languageSet: LanguageSet, expressions: [NSRegularExpression]) throws {
        XCTAssertGreaterThan(languageSet.english.strings.count, 0)
        for (key, englishValue) in languageSet.english.strings {
            let englishSet = matchSet(for: expressions, in: englishValue)

            for (language, languageStrings) in languageSet.other {
                guard let languageValue = languageStrings.strings[key] else {
                    // it is okay for a language to be missing the string if it's new
                    continue
                }

                XCTAssertEqual(
                    matchSet(for: expressions, in: languageValue),
                    englishSet,
                    "for language '\(language)' in table '\(languageSet.name)' with key '\(key)'"
                )
            }
        }
    }
}
