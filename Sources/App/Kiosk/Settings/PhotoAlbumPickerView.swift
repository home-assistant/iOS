import Photos
import PhotosUI
import SwiftUI

// MARK: - Photo Album Picker View

/// View for selecting photo albums from the device's photo library
public struct PhotoAlbumPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAlbumIds: [String]

    @State private var albums: [PHAssetCollection] = []
    @State private var isLoading = true
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var albumPhotoCounts: [String: Int] = [:]

    let title: String
    let albumType: AlbumType

    enum AlbumType {
        case local
        case iCloud
    }

    public init(
        selectedAlbumIds: Binding<[String]>,
        albumType: AlbumType = .local,
        title: String = "Select Albums"
    ) {
        _selectedAlbumIds = selectedAlbumIds
        self.albumType = albumType
        self.title = title
    }

    public var body: some View {
        Group {
            switch authorizationStatus {
            case .authorized, .limited:
                albumList
            case .denied, .restricted:
                permissionDeniedView
            case .notDetermined:
                requestingPermissionView
            @unknown default:
                permissionDeniedView
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkAuthorization()
        }
    }

    // MARK: - Permission Views

    private var requestingPermissionView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Requesting photo access...")
                .foregroundColor(.secondary)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Photo Access Required")
                .font(.headline)

            Text("Please grant photo access in Settings to select albums for the screensaver.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Album List

    private var albumList: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading albums...")
                        .foregroundColor(.secondary)
                }
            } else if albums.isEmpty {
                Text("No albums found")
                    .foregroundColor(.secondary)
            } else {
                // All Photos option
                allPhotosRow

                // Smart Albums section
                if !smartAlbums.isEmpty {
                    Section("Smart Albums") {
                        ForEach(smartAlbums, id: \.localIdentifier) { album in
                            albumRow(album)
                        }
                    }
                }

                // User Albums section
                if !userAlbums.isEmpty {
                    Section("Albums") {
                        ForEach(userAlbums, id: \.localIdentifier) { album in
                            albumRow(album)
                        }
                    }
                }

                // Shared Albums (iCloud) section
                if albumType == .iCloud && !sharedAlbums.isEmpty {
                    Section("Shared Albums") {
                        ForEach(sharedAlbums, id: \.localIdentifier) { album in
                            albumRow(album)
                        }
                    }
                }
            }

            // Selection summary
            if !selectedAlbumIds.isEmpty {
                Section {
                    Button(role: .destructive) {
                        selectedAlbumIds.removeAll()
                    } label: {
                        Label("Clear Selection", systemImage: "xmark.circle")
                    }
                } footer: {
                    Text("\(selectedAlbumIds.count) album(s) selected")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var allPhotosRow: some View {
        Button {
            toggleSelection("all_photos")
        } label: {
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundColor(.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("All Photos")
                        .foregroundColor(.primary)
                    Text("Use all photos in library")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if selectedAlbumIds.contains("all_photos") {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    private func albumRow(_ album: PHAssetCollection) -> some View {
        Button {
            toggleSelection(album.localIdentifier)
        } label: {
            HStack {
                // Album icon
                Image(systemName: iconForAlbum(album))
                    .foregroundColor(.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.localizedTitle ?? "Untitled")
                        .foregroundColor(.primary)

                    if let count = albumPhotoCounts[album.localIdentifier] {
                        Text("\(count) photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if selectedAlbumIds.contains(album.localIdentifier) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    // MARK: - Album Filtering

    private var smartAlbums: [PHAssetCollection] {
        albums.filter { $0.assetCollectionType == .smartAlbum }
    }

    private var userAlbums: [PHAssetCollection] {
        albums.filter { $0.assetCollectionType == .album }
    }

    private var sharedAlbums: [PHAssetCollection] {
        albums.filter { $0.assetCollectionType == .moment }
    }

    // MARK: - Actions

    private func toggleSelection(_ identifier: String) {
        if selectedAlbumIds.contains(identifier) {
            selectedAlbumIds.removeAll { $0 == identifier }
        } else {
            // If selecting "all_photos", clear other selections
            if identifier == "all_photos" {
                selectedAlbumIds = ["all_photos"]
            } else {
                // Remove "all_photos" if selecting specific albums
                selectedAlbumIds.removeAll { $0 == "all_photos" }
                selectedAlbumIds.append(identifier)
            }
        }
    }

    // MARK: - Data Loading

    private func checkAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch authorizationStatus {
        case .authorized, .limited:
            loadAlbums()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self.loadAlbums()
                    }
                }
            }
        default:
            isLoading = false
        }
    }

    private func loadAlbums() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var fetchedAlbums: [PHAssetCollection] = []
            var counts: [String: Int] = [:]

            // Fetch smart albums
            let smartAlbumsResult = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .any,
                options: nil
            )
            smartAlbumsResult.enumerateObjects { collection, _, _ in
                // Filter to only include albums with photos
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                if assets.count > 0 {
                    fetchedAlbums.append(collection)
                    counts[collection.localIdentifier] = assets.count
                }
            }

            // Fetch user albums
            let userAlbumsResult = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .any,
                options: nil
            )
            userAlbumsResult.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                if assets.count > 0 {
                    fetchedAlbums.append(collection)
                    counts[collection.localIdentifier] = assets.count
                }
            }

            // For iCloud, also fetch shared albums
            if self.albumType == .iCloud {
                let sharedResult = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .albumCloudShared,
                    options: nil
                )
                sharedResult.enumerateObjects { collection, _, _ in
                    let assets = PHAsset.fetchAssets(in: collection, options: nil)
                    if assets.count > 0 {
                        fetchedAlbums.append(collection)
                        counts[collection.localIdentifier] = assets.count
                    }
                }
            }

            DispatchQueue.main.async {
                self.albums = fetchedAlbums
                self.albumPhotoCounts = counts
                self.isLoading = false
            }
        }
    }

    private func iconForAlbum(_ album: PHAssetCollection) -> String {
        switch album.assetCollectionSubtype {
        case .smartAlbumFavorites:
            return "heart.fill"
        case .smartAlbumRecentlyAdded:
            return "clock.fill"
        case .smartAlbumVideos:
            return "video.fill"
        case .smartAlbumSelfPortraits:
            return "person.crop.square.fill"
        case .smartAlbumPanoramas:
            return "pano.fill"
        case .smartAlbumScreenshots:
            return "camera.viewfinder"
        case .smartAlbumLivePhotos:
            return "livephoto"
        case .smartAlbumDepthEffect:
            return "camera.aperture"
        case .smartAlbumBursts:
            return "square.stack.3d.up.fill"
        case .smartAlbumTimelapses:
            return "timelapse"
        case .smartAlbumSlomoVideos:
            return "slowmo"
        case .smartAlbumAnimated:
            return "square.stack.3d.forward.dottedline.fill"
        case .smartAlbumLongExposures:
            return "camera.filters"
        case .smartAlbumRAW:
            return "camera.badge.ellipsis"
        case .albumCloudShared:
            return "person.2.fill"
        default:
            return "photo.on.rectangle"
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    NavigationView {
        PhotoAlbumPickerView(
            selectedAlbumIds: .constant(["all_photos"]),
            albumType: .local
        )
    }
}
