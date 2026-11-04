import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The bar avatar: the cached picture first, then the one the server has once the user is known.
@Suite(.sharedState)
@MainActor
struct NativeTabBarAvatarLoaderTests {
    private final class Recorder {
        var images: [UIImage] = []
    }

    private struct Context {
        let viewModel: NativeTabBarViewModel
        let api: HomeAssistantAPI
        let connection: HAMockConnection
        let diskCache: FakeDiskCache
    }

    private func withContext(_ body: (Context) async throws -> Void) async throws {
        let previousCachedApis = Current.cachedApis
        let previousDiskCache = Current.diskCache
        defer {
            Current.cachedApis = previousCachedApis
            Current.diskCache = previousDiskCache
        }
        let suiteName = "NativeTabBarAvatarLoaderTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let server = Server.fake()
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        let diskCache = FakeDiskCache()
        diskCache.storage[api.profilePictureCacheKey] = try #require(makePicture().pngData())
        Current.diskCache = diskCache

        let overlayState = WebFrontendOverlayState()
        let viewModel = NativeTabBarViewModel(
            sidebar: MacSidebarViewModel(
                server: server,
                overlayState: overlayState,
                snapshotStore: MacSidebarSnapshotStore(userDefaults: userDefaults)
            ),
            overlayState: overlayState,
            tabBarState: NativeTabBarState(),
            extrasStore: NativeTabBarExtrasStore(userDefaults: userDefaults),
            servers: { [server] }
        )
        try await body(Context(viewModel: viewModel, api: api, connection: connection, diskCache: diskCache))
        viewModel.stop()
    }

    @available(iOS 26, *)
    @Test("An active loader shows the cached picture, then fetches the user's own once the user is known")
    func loadsTheCachedPictureThenTheUsersOwn() async throws {
        try await withContext { context in
            let recorder = Recorder()
            let window = show(context.viewModel, isActive: true, recorder: recorder)
            defer { window.isHidden = true }

            let showedThePicture = await waitUntil { recorder.images.last.map(Self.showsThePicture) ?? false }
            #expect(showedThePicture)
            #expect(context.diskCache.storage[context.api.profileNameCacheKey] == nil)

            context.viewModel.start()
            let userRequest = await waitUntil {
                context.connection.pendingRequests.contains { $0.request.type.command == "auth/current_user" }
            }
            #expect(userRequest)
            for pending in context.connection.pendingRequests
                where pending.request.type.command == "auth/current_user" {
                pending.completion(.success(.dictionary([
                    "id": "user", "name": "Jane", "is_owner": true, "is_admin": true,
                ])))
            }

            let fetchedForTheUser = await waitUntil {
                context.diskCache.storage[context.api.profileNameCacheKey] as? String == "Jane"
            }
            #expect(fetchedForTheUser)
            #expect(recorder.images.last.map(Self.showsThePicture) == true)
        }
    }

    @available(iOS 26, *)
    @Test("An inactive loader keeps the initial and never touches the cache")
    func inactiveLoaderShowsTheInitial() async throws {
        try await withContext { context in
            let recorder = Recorder()
            let window = show(context.viewModel, isActive: false, recorder: recorder)
            defer { window.isHidden = true }

            try? await Task.sleep(for: .milliseconds(300))
            let first = try #require(recorder.images.first)
            #expect(!Self.showsThePicture(first))
            #expect(first.size.width == NativeTabBarAvatarImage.barButtonSize)
            #expect(recorder.images.allSatisfy { !Self.showsThePicture($0) })
        }
    }

    @available(iOS 26, *)
    private func show(_ viewModel: NativeTabBarViewModel, isActive: Bool, recorder: Recorder) -> UIWindow {
        let loader = NativeTabBarAvatarLoader(viewModel: viewModel, isActive: isActive) { avatar in
            Image(uiImage: avatar)
                .onAppear { recorder.images.append(avatar) }
                .onChange(of: avatar) { recorder.images.append(avatar) }
        }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: CGSize(width: 120, height: 120))
        window.rootViewController = UIHostingController(rootView: loader)
        window.isHidden = false
        window.layoutIfNeeded()
        return window
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    private func makePicture() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 56, height: 56)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 56, height: 56))
        }
    }

    /// The picture is orange where the initial's placeholder is the brand blue.
    private static func showsThePicture(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(cgImage, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        }
        return pixel[0] > 200 && pixel[2] < 100
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
