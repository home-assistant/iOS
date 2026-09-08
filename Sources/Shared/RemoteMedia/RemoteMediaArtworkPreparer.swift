import Foundation

/// Fetches and downsamples album art in the host app, then leaves it in the App Group for the
/// extension to read.
///
/// Keeping decoding here leaves the extension with only a small prepared file to read within its
/// 6144 KB memory budget.
public actor RemoteMediaArtworkPreparer {
    /// Now Playing renders artwork at screen size at most; anything larger is wasted bytes in the
    /// group container and wasted decode in the extension.
    static let maximumPixelSize = RemoteMediaArtworkDownsampler.maximumPixelSize
    static let compressionQuality = RemoteMediaArtworkDownsampler.compressionQuality
    static let timeout: TimeInterval = 15
    /// Home Assistant proxies album art from the player, which is screen-sized at worst.
    static let maximumSourceBytes = 10 * 1024 * 1024

    private var inFlight: [String: Task<RemoteMediaArtworkDescriptor?, Never>] = [:]

    public init() {}

    /// The descriptor for this state's artwork, preparing it first if it is not cached yet.
    /// Returns `nil` whenever artwork cannot be produced — it is optional and never fails a session.
    public func descriptor(for state: RemoteMediaEntityState) async -> RemoteMediaArtworkDescriptor? {
        guard let source = state.artworkSource, !source.isEmpty else { return nil }
        let snapshot = state.snapshot
        let key = RemoteMediaArtworkCache.key(
            sessionId: snapshot.id,
            trackId: snapshot.trackId,
            source: source
        )
        let descriptor = RemoteMediaArtworkDescriptor(cacheKey: key)
        if RemoteMediaArtworkCache.contains(descriptor) { return descriptor }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<RemoteMediaArtworkDescriptor?, Never> { [serverId = snapshot.selection.serverId] in
            do {
                let data = try await Self.download(source: source, serverId: serverId)
                guard let prepared = Self.downsample(data) else { throw RemoteMediaError.invalidArtwork }
                try RemoteMediaArtworkCache.store(prepared, for: descriptor)
                return descriptor
            } catch {
                Current.Log.error("Remote media artwork preparation failed: \(error)")
                return nil
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    private static func download(source: String, serverId: String) async throws -> Data {
        let server = Current.servers.server(forServerIdentifier: serverId)
        let api = server.flatMap { Current.api(for: $0) }
        guard let server, let api,
              let url = URL(string: source), url.user == nil, url.password == nil else {
            throw RemoteMediaError.invalidArtwork
        }
        let activeURL = await server.activeURL()
        let resolved: URL
        let needsAuth: Bool
        if url.scheme == nil {
            // `entity_picture` is a server-relative path carrying a signed token in its query.
            // Resolve it here: appending it as a path component percent-encodes the `?` and loses
            // the token.
            guard source.hasPrefix("/"), !source.hasPrefix("//"),
                  let activeURL,
                  let absolute = URL(string: source, relativeTo: activeURL)?.absoluteURL else {
                throw RemoteMediaError.invalidArtwork
            }
            resolved = absolute
            needsAuth = true
        } else {
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                throw RemoteMediaError.invalidArtwork
            }
            resolved = url
            // Only the active Home Assistant origin may receive Home Assistant credentials.
            needsAuth = activeURL.map { url.baseIsEqual(to: $0) } ?? false
        }

        let file = try await api.DownloadDataAt(url: resolved, needsAuth: needsAuth)
            .asyncValue(timeout: timeout)
        defer { try? FileManager.default.removeItem(at: file) }
        let values = try file.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= maximumSourceBytes else {
            throw RemoteMediaError.invalidArtwork
        }
        return try Data(contentsOf: file)
    }

    /// Downsamples with ImageIO rather than decoding at full resolution, and never upscales.
    static func downsample(_ data: Data, maximumPixelSize: Int = maximumPixelSize) -> Data? {
        RemoteMediaArtworkDownsampler.downsample(data, maximumPixelSize: maximumPixelSize)
    }
}
