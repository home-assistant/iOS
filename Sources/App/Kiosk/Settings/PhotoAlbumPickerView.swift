import Photos
import PhotosUI
import SwiftUI

// MARK: - Photo Album Picker View

/// View for selecting photo albums from the device's photo library
public struct PhotoAlbumPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAlbumIds: [String]

    /// Type of albums to show
    let albumType: AlbumType

    /// Title for the view
    let title: String

    @State private var albums: [AlbumInfo] = []
    @State private var isLoading = true
    @State private var permissionStatus: PHAuthorizationStatus = .notDetermined
    @State private var searchText = ""

    public enum AlbumType {
        case local
        case iCloud

        var subtitle: String {
            switch self {
            case .local: return "Select albums from this device"
            case .iCloud: return "Select iCloud shared albums"
            }
        }
    }

    public init(selectedAlbumIds: Binding<[String]>, albumType: AlbumType, title: String = "Select Albums") {
        _selectedAlbumIds = selectedAlbumIds
        self.albumType = albumType
        self.title = title
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch permissionStatus {
                case .authorized, .limited:
                    albumListContent
                case .denied, .restricted:
                    permissionDeniedView
                case .notDetermined:
                    requestPermissionView
                @unknown default:
                    requestPermissionView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                checkPermission()
            }
        }
    }

    // MARK: - Album List Content

    private var albumListContent: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading albums...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if albums.isEmpty {
                ContentUnavailableView(
                    "No Albums Found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(albumType == .iCloud ? "No iCloud shared albums available" : "No albums found on this device")
                )
            } else {
                List {
                    if !searchText.isEmpty {
                        filteredAlbumsList
                    } else {
                        allAlbumsList
                    }
                }
                .searchable(text: $searchText, prompt: "Search albums")
            }
        }
    }

    private var allAlbumsList: some View {
        Group {
            // Smart Albums section
            let smartAlbums = albums.filter { $0.isSmartAlbum }
            if !smartAlbums.isEmpty {
                Section("Smart Albums") {
                    ForEach(smartAlbums) { album in
                        albumRow(album)
                    }
                }
            }

            // User Albums section
            let userAlbums = albums.filter { !$0.isSmartAlbum }
            if !userAlbums.isEmpty {
                Section("My Albums") {
                    ForEach(userAlbums) { album in
                        albumRow(album)
                    }
                }
            }
        }
    }

    private var filteredAlbumsList: some View {
        let filtered = albums.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return Section {
            ForEach(filtered) { album in
                albumRow(album)
            }
        }
    }

    private func albumRow(_ album: AlbumInfo) -> some View {
        HStack {
            // Album thumbnail
            if let thumbnail = album.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.body)
                Text("\(album.assetCount) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Selection indicator
            if selectedAlbumIds.contains(album.identifier) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: album)
        }
    }

    // MARK: - Permission Views

    private var requestPermissionView: some View {
        ContentUnavailableView {
            Label("Photo Access Required", systemImage: "photo.on.rectangle")
        } description: {
            Text("Please grant access to your photo library to select albums for the screensaver.")
        } actions: {
            Button("Grant Access") {
                requestPermission()
            }
            .buttonStyle(.bordered)
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Photo Access Denied", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Photo library access was denied. Please enable it in Settings to select albums.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Permission Handling

    private func checkPermission() {
        permissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if permissionStatus == .authorized || permissionStatus == .limited {
            loadAlbums()
        }
    }

    private func requestPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                permissionStatus = status
                if status == .authorized || status == .limited {
                    loadAlbums()
                }
            }
        }
    }

    // MARK: - Album Loading

    private func loadAlbums() {
        isLoading = true
        albums = []

        DispatchQueue.global(qos: .userInitiated).async {
            var loadedAlbums: [AlbumInfo] = []

            // Fetch smart albums (like Favorites, Recent, etc.)
            let smartAlbumTypes: [PHAssetCollectionSubtype] = [
                .smartAlbumFavorites,
                .smartAlbumRecentlyAdded,
                .smartAlbumUserLibrary,
                .smartAlbumSelfPortraits,
                .smartAlbumPanoramas,
                .smartAlbumScreenshots,
                .smartAlbumBursts,
                .smartAlbumLivePhotos,
            ]

            for subtype in smartAlbumTypes {
                let fetchResult = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: subtype,
                    options: nil
                )

                fetchResult.enumerateObjects { collection, _, _ in
                    if let albumInfo = createAlbumInfo(from: collection, isSmartAlbum: true) {
                        loadedAlbums.append(albumInfo)
                    }
                }
            }

            // Fetch user-created albums
            let userAlbumsFetch = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .any,
                options: nil
            )

            userAlbumsFetch.enumerateObjects { collection, _, _ in
                if let albumInfo = createAlbumInfo(from: collection, isSmartAlbum: false) {
                    loadedAlbums.append(albumInfo)
                }
            }

            // For iCloud, also fetch shared albums
            if albumType == .iCloud {
                let sharedAlbumsFetch = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .albumCloudShared,
                    options: nil
                )

                sharedAlbumsFetch.enumerateObjects { collection, _, _ in
                    if let albumInfo = createAlbumInfo(from: collection, isSmartAlbum: false) {
                        loadedAlbums.append(albumInfo)
                    }
                }
            }

            // Sort: smart albums first, then by name
            loadedAlbums.sort { lhs, rhs in
                if lhs.isSmartAlbum != rhs.isSmartAlbum {
                    return lhs.isSmartAlbum
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            DispatchQueue.main.async {
                albums = loadedAlbums
                isLoading = false
            }
        }
    }

    private func createAlbumInfo(from collection: PHAssetCollection, isSmartAlbum: Bool) -> AlbumInfo? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)

        // Skip albums with no photos
        guard assets.count > 0 else { return nil }

        // Get thumbnail from the first asset
        var thumbnail: UIImage?
        if let firstAsset = assets.firstObject {
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: firstAsset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                thumbnail = image
            }
        }

        return AlbumInfo(
            identifier: collection.localIdentifier,
            title: collection.localizedTitle ?? "Untitled Album",
            assetCount: assets.count,
            thumbnail: thumbnail,
            isSmartAlbum: isSmartAlbum
        )
    }

    // MARK: - Selection

    private func toggleSelection(for album: AlbumInfo) {
        if let index = selectedAlbumIds.firstIndex(of: album.identifier) {
            selectedAlbumIds.remove(at: index)
        } else {
            selectedAlbumIds.append(album.identifier)
        }
    }
}

// MARK: - Album Info Model

struct AlbumInfo: Identifiable {
    let id = UUID()
    let identifier: String
    let title: String
    let assetCount: Int
    let thumbnail: UIImage?
    let isSmartAlbum: Bool
}

// MARK: - Preview

#Preview {
    PhotoAlbumPickerView(
        selectedAlbumIds: .constant(["test-album-1"]),
        albumType: .local
    )
}
