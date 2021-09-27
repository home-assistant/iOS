import SwiftUI
import Shared

private struct WidgetCacheKey: EnvironmentKey {
    static let defaultValue = WidgetCache()
}

extension EnvironmentValues {
    var widgetCache: WidgetCache {
        get { self[WidgetCacheKey.self] }
        set { self[WidgetCacheKey.self] = newValue }
    }
}

class WidgetCache {
    func value<T: Codable>(for key: String) throws -> T {
        let url = URL(for: key)
        let data = try Data(contentsOf: url, options: [])
        return try JSONDecoder().decode(T.self, from: data)
    }

    func set<T: Codable>(_ value: T, for key: String) throws {
        let url = URL(for: key)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    private class func URL(containerName: String) -> URL {
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("WidgetCache")
            .appendingPathComponent(containerName)

        try? fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return url
    }

    let container: URL
    init(containerName: String = "Default") {
        self.container = Self.URL(containerName: containerName)
    }

    func URL(for key: String) -> URL {
        container.appendingPathComponent("\(key).json")
    }
}
