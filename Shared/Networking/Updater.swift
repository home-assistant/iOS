import Foundation
import PromiseKit
import Version

public struct AvailableUpdate: Codable {
    public var id: Int
    public var htmlUrl: URL
    public var tagName: String
    public var name: String
    public var body: String

    static func joinedVersionString(version: String, build: String) -> String {
        String(format: "%@/%@", version, build)
    }

    var versionString: String {
        let values = Array(
            tagName
                .split(separator: "/")
                .dropFirst()
                .map { String($0) }
        )
        if values.count >= 2 {
            return Self.joinedVersionString(version: values[0], build: values[1])
        } else {
            return values.joined()
        }
    }

    public struct Asset: Codable {
        var browserDownloadUrl: URL
        var name: String
    }
    public var assets: [Asset]
}

public class Updater {
    private var apiUrl: URL { URL(string: "https://api.github.com/repos/home-assistant/ios/releases?per_page=5")! }

    private enum UpdateError: LocalizedError {
        case unsupportedPlatform
        case onLatestVersion

        var errorDescription: String? {
            switch self {
            case .unsupportedPlatform:
                return "<unsupported platform>"
            case .onLatestVersion:
                return L10n.Updater.NoUpdatesAvailable.onLatestVersion
            }
        }
    }

    public func check() -> Promise<AvailableUpdate> {
        guard Current.isCatalyst else {
            return .init(error: UpdateError.unsupportedPlatform)
        }

        return firstly {
            URLSession.shared.dataTask(.promise, with: apiUrl)
        }.map { data, _ -> [AvailableUpdate] in
            return try with(JSONDecoder()) {
                $0.keyDecodingStrategy = .convertFromSnakeCase
            }.decode([AvailableUpdate].self, from: data)
        }.get { updates in
            Current.Log.info("found releases: \(updates)")
        }.map { updates in
            let current = AvailableUpdate.joinedVersionString(version: Constants.version, build: Constants.build)
            if let first = updates.first(where: { !$0.assets.isEmpty }) {
                // skip over any without assets, but then only check the version numbrer of the first one
                if first.versionString == current {
                    // the same version number, so no update is available
                    throw UpdateError.onLatestVersion
                } else {
                    // not the same version number, so an update is available
                    return first
                }
            } else {
                // Response included updates, but none had assets, assume transient API issue and don't share
                throw UpdateError.onLatestVersion
            }
        }
    }
}
