import Foundation
import PromiseKit
import Version
import PMKFoundation

public struct AvailableUpdate: Codable, Comparable {
    public var id: Int
    public var htmlUrl: URL
    public var tagName: String
    public var name: String
    public var body: String
    public var prerelease: Bool

    var version: Version {
        let parts = versionParts
        var version = (try? Version(hassVersion: parts.version)) ?? Version()
        version.build = parts.build
        return version
    }

    private var versionParts: (version: String, build: String) {
        let values = Array(
            tagName
                .split(separator: "/")
                .dropFirst()
                .map { String($0) }
        )
        if values.count >= 2 {
            return (version: values[0], build: values[1])
        } else {
            return (version: values.joined(), build: "-1")
        }
    }

    public struct Asset: Codable {
        var browserDownloadUrl: URL
        var name: String
    }

    public var assets: [Asset]

    public static func < (lhs: AvailableUpdate, rhs: AvailableUpdate) -> Bool {
        let lhsVersion = lhs.version
        let rhsVersion = rhs.version
        if lhsVersion < rhsVersion {
            return true
        } else if lhsVersion == rhsVersion {
            return lhsVersion.compare(buildOf: rhsVersion) == .orderedAscending
        } else {
            return false
        }
    }

    public static func == (lhs: AvailableUpdate, rhs: AvailableUpdate) -> Bool {
        lhs.version === rhs.version
    }
}

public class Updater {
    private var apiUrl: URL { URL(string: "https://api.github.com/repos/home-assistant/ios/releases?per_page=25")! }

    enum UpdateError: LocalizedError {
        case unsupportedPlatform
        case onLatestVersion
        case privacyDisabled

        var errorDescription: String? {
            switch self {
            case .unsupportedPlatform:
                return "<unsupported platform>"
            case .privacyDisabled:
                return "<privacy disabled>"
            case .onLatestVersion:
                return L10n.Updater.NoUpdatesAvailable.onLatestVersion
            }
        }
    }

    public var isSupported: Bool {
        Current.isCatalyst && !Current.isAppStore
    }

    public func check(dueToUserInteraction: Bool) -> Promise<AvailableUpdate> {
        guard isSupported else {
            return .init(error: UpdateError.unsupportedPlatform)
        }

        guard Current.settingsStore.privacy.updates || dueToUserInteraction else {
            return .init(error: UpdateError.privacyDisabled)
        }

        return firstly {
            URLSession.shared.dataTask(.promise, with: apiUrl)
        }.map { data, _ -> [AvailableUpdate] in
            try with(JSONDecoder()) {
                $0.keyDecodingStrategy = .convertFromSnakeCase
            }.decode([AvailableUpdate].self, from: data)
        }.get { updates in
            Current.Log.info("found releases: \(updates)")
        }.filterValues { release in
            let hasAssets = release.assets.isEmpty == false
            let isCorrectReleaseType: Bool = {
                if Current.settingsStore.privacy.updatesIncludeBetas {
                    return true
                } else {
                    return !release.prerelease
                }
            }()
            return isCorrectReleaseType && hasAssets
        }.map { updates in
            // grab the 'newest' one
            guard let first = updates.sorted(by: { $1 < $0 }).first else {
                // Response included updates, but none had assets, assume transient API issue and don't share
                throw UpdateError.onLatestVersion
            }

            let currentVersion = Current.clientVersion()
            let firstVersion = first.version

            if currentVersion < firstVersion {
                return first
            } else if currentVersion == firstVersion,
                      currentVersion.compare(buildOf: firstVersion) == .orderedAscending {
                return first
            } else {
                // the same version number, so no update is available
                throw UpdateError.onLatestVersion
            }
        }
    }
}
