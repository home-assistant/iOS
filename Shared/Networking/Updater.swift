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

    public func check() -> Promise<AvailableUpdate> {
        firstly {
            URLSession.shared.dataTask(.promise, with: apiUrl)
        }.map { data, _ -> [AvailableUpdate] in
            return try with(JSONDecoder()) {
                $0.keyDecodingStrategy = .convertFromSnakeCase
            }.decode([AvailableUpdate].self, from: data)
        }.get { updates in
            Current.Log.info("found releases: \(updates)")
        }.compactMap { updates in
            let current = AvailableUpdate.joinedVersionString(version: Constants.version, build: Constants.build)
            if let first = updates.first(where: { !$0.assets.isEmpty }), first.versionString != current {
                // skip over any without assets, but then only check the version numbrer of the first one
                return first
            } else {
                return nil
            }
        }
    }
}
