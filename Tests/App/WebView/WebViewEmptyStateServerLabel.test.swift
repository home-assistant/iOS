@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@Suite(.serialized)
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

        let expected = await settledImage(of: WebViewEmptyStateServerLabel(server: server, userName: "bruno"))
        let window = show(WebViewEmptyStateServerLabel(server: server))
        defer { window.isHidden = true }

        let diffing = Diffing<UIImage>.image(precision: 0.99, perceptualPrecision: 0.99)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        var difference = diffing.diff(expected, image(of: window))
        while difference != nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            difference = diffing.diff(expected, image(of: window))
        }
        if let difference {
            Issue.record("The cached user did not show: \(difference.0)")
        }
    }

    @MainActor
    private func settledImage(of label: WebViewEmptyStateServerLabel) async -> UIImage {
        let window = show(label)
        defer { window.isHidden = true }
        try? await Task.sleep(for: .seconds(0.5))
        return image(of: window)
    }

    @MainActor
    private func show(_ label: WebViewEmptyStateServerLabel) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.rootViewController = UIHostingController(rootView: label)
        window.isHidden = false
        window.layoutIfNeeded()
        return window
    }

    @MainActor
    private func image(of window: UIWindow) -> UIImage {
        window.layoutIfNeeded()
        return UIGraphicsImageRenderer(bounds: window.bounds).image { context in
            window.layer.render(in: context.cgContext)
        }
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
