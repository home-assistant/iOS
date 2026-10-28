@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

struct WebViewEmptyStateServerLabelTests {
    private static let size = CGSize(width: 240, height: 60)

    @MainActor @Test func userInitialSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: WebViewEmptyStateServerLabel(server: ServerFixture.standard, userName: "bruno"),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size.width, height: Self.size.height),
            named: "empty-state-server-label-user-initial"
        )
    }

    @MainActor @Test func profilePictureSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: WebViewEmptyStateServerLabel(server: ServerFixture.standard, profilePicture: makePicture()),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size.width, height: Self.size.height),
            named: "empty-state-server-label-profile-picture"
        )
    }

    @MainActor @Test func withoutAProfileSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: WebViewEmptyStateServerLabel(server: ServerFixture.standard),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size.width, height: Self.size.height),
            named: "empty-state-server-label-without-profile"
        )
    }

    @MainActor @Test func showsTheCachedUserWhileDisconnected() async throws {
        let previousServers = Current.servers
        let previousDiskCache = Current.diskCache
        defer {
            Current.servers = previousServers
            Current.diskCache = previousDiskCache
        }
        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        let server = try #require(servers.all.first)
        let api = try #require(Current.api(for: server))
        let diskCache = FakeDiskCache()
        diskCache.storage[api.profileNameCacheKey] = "bruno"
        Current.diskCache = diskCache

        let loaded = await render(WebViewEmptyStateServerLabel(server: server))
        let expected = await render(WebViewEmptyStateServerLabel(server: server, userName: "bruno"))

        let diffing = Diffing<UIImage>.image(precision: 0.99, perceptualPrecision: 0.99)
        if let difference = diffing.diff(expected, loaded) {
            Issue.record("The cached user did not show: \(difference.0)")
        }
    }

    @MainActor
    private func render(_ label: WebViewEmptyStateServerLabel) async -> UIImage {
        let controller = UIHostingController(rootView: label)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try? await Task.sleep(for: .seconds(0.5))
        window.layoutIfNeeded()

        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
            window.layer.render(in: context.cgContext)
        }
        window.isHidden = true
        return image
    }

    private func makePicture() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 56, height: 56)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 56, height: 56))
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 28, width: 56, height: 28))
        }
    }

    private final class FakeDiskCache: DiskCache {
        enum FakeDiskCacheError: Error {
            case missing
        }

        var storage = [String: Any]()

        func value<T: Codable>(for key: String) -> Promise<T> {
            if let value = storage[key] as? T {
                return .value(value)
            }
            return Promise(error: FakeDiskCacheError.missing)
        }

        func set(_ value: some Codable, for key: String) -> Promise<Void> {
            storage[key] = value
            return .value(())
        }

        func delete(for key: String) -> Promise<Void> {
            storage[key] = nil
            return .value(())
        }
    }
}
