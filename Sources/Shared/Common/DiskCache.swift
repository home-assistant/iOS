import Foundation
import SwiftUI

public protocol DiskCache {
    func value<T: Codable>(for key: String) throws -> T
    func set<T: Codable>(_ value: T, for key: String) throws
}

private struct DiskCacheKey: EnvironmentKey {
    static let defaultValue = Current.diskCache
}

// also in AppEnvironment
public extension EnvironmentValues {
    var diskCache: DiskCache {
        get { self[DiskCacheKey.self] }
        set { self[DiskCacheKey.self] = newValue }
    }
}

public final class DiskCacheImpl: DiskCache {
    public func value<T: Codable>(for key: String) throws -> T {
        let url = URL(for: key)
        let data = try Data(contentsOf: url, options: [])
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func set<T: Codable>(_ value: T, for key: String) throws {
        let url = URL(for: key)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    private class func URL(containerName: String) -> URL {
        let fileManager = FileManager.default
        let url = Constants.AppGroupContainer
            .appendingPathComponent("DiskCache")
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
