import Combine
import Foundation
import HAKit
import Photos
import Shared
import UIKit

// MARK: - Photo Manager

/// Manages fetching photos from multiple sources for the screensaver
@MainActor
public final class PhotoManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = PhotoManager()

    // MARK: - Published State

    /// Currently available photos
    @Published public private(set) var photos: [ScreensaverPhoto] = []

    /// Current photo index
    @Published public private(set) var currentIndex: Int = 0

    /// Whether we're currently loading photos
    @Published public private(set) var isLoading: Bool = false

    /// Error message if loading failed
    @Published public private(set) var errorMessage: String?

    /// Photos authorization status
    @Published public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined

    // MARK: - Private

    private var loadTask: Task<Void, Never>?
    private var rotationTimer: Timer?
    private var settings: KioskSettings { KioskModeManager.shared.settings }

    // MARK: - Initialization

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Public Methods

    /// Load photos from configured sources
    public func loadPhotos() {
        loadTask?.cancel()

        loadTask = Task {
            await loadPhotosAsync()
        }
    }

    /// Start automatic photo rotation
    public func startRotation() {
        stopRotation()

        let interval = settings.photoInterval
        guard interval > 0 else { return }

        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nextPhoto()
            }
        }
    }

    /// Stop automatic photo rotation
    public func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    /// Move to next photo
    public func nextPhoto() {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex + 1) % photos.count
    }

    /// Move to previous photo
    public func previousPhoto() {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex - 1 + photos.count) % photos.count
    }

    /// Get current photo
    public var currentPhoto: ScreensaverPhoto? {
        guard currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }

    /// Request photo library access
    public func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status == .authorized || status == .limited
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func loadPhotosAsync() async {
        isLoading = true
        errorMessage = nil

        var allPhotos: [ScreensaverPhoto] = []

        // Load from each configured source
        switch settings.photoSource {
        case .local:
            allPhotos = await loadLocalPhotos()

        case .iCloud:
            allPhotos = await loadiCloudPhotos()

        case .haMedia:
            allPhotos = await loadHAMediaPhotos()

        case .all:
            async let local = loadLocalPhotos()
            async let iCloud = loadiCloudPhotos()
            async let haMedia = loadHAMediaPhotos()

            let results = await [local, iCloud, haMedia]
            allPhotos = results.flatMap { $0 }
        }

        // Shuffle photos for variety
        photos = allPhotos.shuffled()
        currentIndex = 0
        isLoading = false

        if photos.isEmpty {
            errorMessage = "No photos found"
        }
    }

    private func loadLocalPhotos() async -> [ScreensaverPhoto] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            Current.Log.warning("Photo library access not authorized")
            return []
        }

        return await withCheckedContinuation { continuation in
            var photos: [ScreensaverPhoto] = []

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 100 // Limit to prevent memory issues

            let fetchResult: PHFetchResult<PHAsset>

            // If specific albums are configured, fetch from those
            if !settings.localPhotoAlbums.isEmpty {
                let albumsFetch = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: settings.localPhotoAlbums,
                    options: nil
                )

                var assets: [PHAsset] = []
                albumsFetch.enumerateObjects { collection, _, _ in
                    let assetsFetch = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                    assetsFetch.enumerateObjects { asset, _, _ in
                        assets.append(asset)
                    }
                }

                for asset in assets.prefix(100) {
                    photos.append(ScreensaverPhoto(asset: asset))
                }
            } else {
                // Fetch from all photos
                fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                fetchResult.enumerateObjects { asset, _, _ in
                    photos.append(ScreensaverPhoto(asset: asset))
                }
            }

            Current.Log.info("Loaded \(photos.count) local photos")
            continuation.resume(returning: photos)
        }
    }

    private func loadiCloudPhotos() async -> [ScreensaverPhoto] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return []
        }

        return await withCheckedContinuation { continuation in
            var photos: [ScreensaverPhoto] = []

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 100

            // Fetch from shared albums if configured
            if !settings.iCloudAlbums.isEmpty {
                let sharedAlbumsFetch = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: settings.iCloudAlbums,
                    options: nil
                )

                sharedAlbumsFetch.enumerateObjects { collection, _, _ in
                    let assetsFetch = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                    assetsFetch.enumerateObjects { asset, _, _ in
                        photos.append(ScreensaverPhoto(asset: asset))
                    }
                }
            } else {
                // Fetch from all shared albums
                let sharedAlbums = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .albumCloudShared,
                    options: nil
                )

                sharedAlbums.enumerateObjects { collection, _, stop in
                    let assetsFetch = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                    assetsFetch.enumerateObjects { asset, _, _ in
                        photos.append(ScreensaverPhoto(asset: asset))
                    }

                    if photos.count >= 100 {
                        stop.pointee = true
                    }
                }
            }

            Current.Log.info("Loaded \(photos.count) iCloud photos")
            continuation.resume(returning: photos)
        }
    }

    private func loadHAMediaPhotos() async -> [ScreensaverPhoto] {
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server),
              !settings.haMediaPath.isEmpty else {
            return []
        }

        // Fetch media from Home Assistant Media Browser
        // This is a simplified implementation - full implementation would use HA's media_source API
        do {
            let request = HATypedRequest<HAMediaItems>(request: .init(
                type: "media_source/browse_media",
                data: ["media_content_id": settings.haMediaPath]
            ))

            guard let response = try await api.connection.send(request).promise.value else {
                Current.Log.error("No response from HA media browser")
                return []
            }
            let photos = response.children.compactMap { item -> ScreensaverPhoto? in
                guard item.mediaClass == "image",
                      let urlString = item.mediaContentId,
                      let url = URL(string: urlString) else {
                    return nil
                }
                return ScreensaverPhoto(url: url, title: item.title)
            }

            Current.Log.info("Loaded \(photos.count) HA media photos")
            return Array(photos.prefix(100))
        } catch {
            Current.Log.error("Failed to load HA media photos: \(error)")
            return []
        }
    }
}

// MARK: - Screensaver Photo

/// Represents a photo for the screensaver
public struct ScreensaverPhoto: Identifiable, Equatable {
    public let id: String
    public let source: PhotoSourceType

    /// The PHAsset for local/iCloud photos
    public let asset: PHAsset?

    /// URL for remote photos (HA media)
    public let url: URL?

    /// Optional title/caption
    public let title: String?

    public static func == (lhs: ScreensaverPhoto, rhs: ScreensaverPhoto) -> Bool {
        lhs.id == rhs.id
    }

    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.source = .local
        self.asset = asset
        self.url = nil
        self.title = nil
    }

    init(url: URL, title: String? = nil) {
        self.id = url.absoluteString
        self.source = .remote
        self.asset = nil
        self.url = url
        self.title = title
    }

    /// Load the image for display
    @MainActor
    public func loadImage(targetSize: CGSize) async -> UIImage? {
        switch source {
        case .local:
            return await loadFromAsset(targetSize: targetSize)
        case .remote:
            return await loadFromURL()
        }
    }

    private func loadFromAsset(targetSize: CGSize) async -> UIImage? {
        guard let asset else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .exact

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func loadFromURL() async -> UIImage? {
        guard let url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            Current.Log.error("Failed to load image from URL: \(error)")
            return nil
        }
    }
}

public enum PhotoSourceType {
    case local
    case remote
}

// MARK: - HA Media Items Response

struct HAMediaItems: HADataDecodable {
    let title: String
    let mediaClass: String?
    let mediaContentId: String?
    let children: [HAMediaItem]

    init(data: HAData) throws {
        self.title = try data.decode("title")
        self.mediaClass = try? data.decode("media_class")
        self.mediaContentId = try? data.decode("media_content_id")
        self.children = (try? data.decode("children")) ?? []
    }
}

struct HAMediaItem: HADataDecodable {
    let title: String
    let mediaClass: String?
    let mediaContentId: String?
    let thumbnail: String?

    init(data: HAData) throws {
        self.title = try data.decode("title")
        self.mediaClass = try? data.decode("media_class")
        self.mediaContentId = try? data.decode("media_content_id")
        self.thumbnail = try? data.decode("thumbnail")
    }
}
