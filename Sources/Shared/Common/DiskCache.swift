import Foundation
import PromiseKit
import SwiftUI

public protocol DiskCache {
    func value<T: Codable>(for key: String) -> Promise<T>
    func set<T: Codable>(_ value: T, for key: String) -> Promise<Void>
}

@available(iOS 13, watchOS 6, *)
private struct DiskCacheKey: EnvironmentKey {
    static let defaultValue = Current.diskCache
}

// also in AppEnvironment
@available(iOS 13, watchOS 6, *)
public extension EnvironmentValues {
    var diskCache: DiskCache {
        get { self[DiskCacheKey.self] }
        set { self[DiskCacheKey.self] = newValue }
    }
}

public final class DiskCacheImpl: DiskCache {
    public func value<T: Codable>(for key: String) -> Promise<T> {
        let (promise, seal) = Promise<T>.pending()
        DispatchQueue.global().async { [coordinator, container] in
            var coordinatorError: NSError?
            coordinator.coordinate(
                readingItemAt: Self.URL(in: container, for: key),
                options: [],
                error: &coordinatorError
            ) { url in
                do {
                    let data = try Data(contentsOf: url, options: [])
                    let value = try JSONDecoder().decode(T.self, from: data)
                    seal.fulfill(value)
                } catch {
                    seal.reject(error)
                }
            }

            if let error = coordinatorError {
                seal.reject(error)
            }
        }
        return promise
    }

    public func set<T: Codable>(_ value: T, for key: String) -> Promise<Void> {
        let data: Data

        do {
            // the contents of the value may be unsafe off the thread this is called on
            // we can at least move the write operation itself off the thread
            data = try JSONEncoder().encode(value)
        } catch {
            return .init(error: error)
        }

        let (promise, seal) = Promise<Void>.pending()
        DispatchQueue.global().async { [coordinator, container] in
            var coordinatorError: NSError?
            coordinator.coordinate(
                writingItemAt: Self.URL(in: container, for: key),
                options: [],
                error: &coordinatorError
            ) { url in
                do {
                    try data.write(to: url, options: [])
                    seal.fulfill(())
                } catch {
                    seal.reject(error)
                }
            }
            if let error = coordinatorError {
                seal.reject(error)
            }
        }
        return promise
    }

    private class func URL(containerName: String) -> URL {
        let fileManager = FileManager.default
        let url = Constants.AppGroupContainer
            .appendingPathComponent("DiskCache", isDirectory: true)
            .appendingPathComponent(containerName, isDirectory: false)

        try? fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return url
    }

    var container: URL
    var coordinator: NSFileCoordinator

    init(containerName: String = "Default") {
        self.coordinator = NSFileCoordinator()
        self.container = Self.URL(containerName: containerName)
    }

    static func URL(in container: URL, for key: String) -> URL {
        let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key

        return container.appendingPathComponent("\(escapedKey).json", isDirectory: false)
    }
}
