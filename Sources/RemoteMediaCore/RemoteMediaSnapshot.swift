import Foundation

/// Playback data without any dependency on Apple's session framework or credentials.
///
/// This is a **wire contract**, not just an app model: it is what `RemoteMediaSessionAttributes`
/// encodes, so Home Assistant has to be able to produce exactly this JSON to push a `nowplaying`
/// APNs update. Two consequences follow, and both are deliberate:
///
/// - Every value is a primitive with an unambiguous JSON form. In particular `positionUpdatedAtUnix`
///   is **seconds since 1970-01-01 UTC**, not a `Date`: `JSONEncoder` writes a `Date` in Swift's
///   2001 reference epoch, and asking a Python server to reproduce that would be a permanent trap.
///   `Date` appears only where the extension hands a value to `MediaPlaybackSnapshot`.
/// - Nothing secret may appear here. Credentials live in `RemoteMediaTransportStore`, and the APNs
///   update token stays with the framework; `RemoteMediaAttributeSecrecyTests` enforces both.
public struct RemoteMediaSnapshot: Codable, Equatable, Sendable {
    public let selection: RemoteMediaSelection
    public let deviceName: String
    public let deviceClass: String?
    public let state: String
    public let title: String?
    public let artist: String?
    public let album: String?
    public let contentId: String?
    public let duration: TimeInterval?
    public let position: TimeInterval?
    /// When `position` was measured, in seconds since 1970-01-01 UTC.
    public let positionUpdatedAtUnix: TimeInterval?
    /// Set once the host app has prepared the image; `nil` until then, so a session publishes its
    /// metadata immediately rather than waiting on a download.
    public let artwork: RemoteMediaArtworkDescriptor?
    public let volume: Double?
    public let isMuted: Bool?
    public let features: RemoteMediaFeatures

    public init(
        selection: RemoteMediaSelection,
        deviceName: String,
        deviceClass: String?,
        state: String,
        title: String?,
        artist: String?,
        album: String?,
        contentId: String?,
        duration: TimeInterval?,
        position: TimeInterval?,
        positionUpdatedAtUnix: TimeInterval?,
        artwork: RemoteMediaArtworkDescriptor?,
        volume: Double?,
        isMuted: Bool?,
        features: RemoteMediaFeatures
    ) {
        self.selection = selection
        self.deviceName = deviceName
        self.deviceClass = deviceClass
        self.state = state
        self.title = title
        self.artist = artist
        self.album = album
        self.contentId = contentId
        self.duration = duration
        self.position = position
        self.positionUpdatedAtUnix = positionUpdatedAtUnix
        self.artwork = artwork
        self.volume = volume
        self.isMuted = isMuted
        self.features = features
    }

    enum CodingKeys: String, CodingKey {
        case selection
        case deviceName
        case deviceClass
        case state
        case title
        case artist
        case album
        case contentId
        case duration
        case position
        case positionUpdatedAtUnix
        case artwork
        case volume
        case isMuted
        case features
    }

    /// Carried only to read attributes an earlier development build cached, which encoded a `Date`.
    private enum LegacyCodingKeys: String, CodingKey {
        case positionUpdatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selection = try container.decode(RemoteMediaSelection.self, forKey: .selection)
        self.deviceName = try container.decode(String.self, forKey: .deviceName)
        self.deviceClass = try container.decodeIfPresent(String.self, forKey: .deviceClass)
        self.state = try container.decode(String.self, forKey: .state)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
        self.album = try container.decodeIfPresent(String.self, forKey: .album)
        self.contentId = try container.decodeIfPresent(String.self, forKey: .contentId)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.position = try container.decodeIfPresent(TimeInterval.self, forKey: .position)
        self.artwork = try container.decodeIfPresent(RemoteMediaArtworkDescriptor.self, forKey: .artwork)
        self.volume = try container.decodeIfPresent(Double.self, forKey: .volume)
        self.isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted)
        self.features = try container.decode(RemoteMediaFeatures.self, forKey: .features)

        if let unix = try container.decodeIfPresent(TimeInterval.self, forKey: .positionUpdatedAtUnix) {
            self.positionUpdatedAtUnix = unix
        } else {
            // The system hands back attributes encoded by whichever build started the session, and
            // the builds before this schema wrote a `Date` — Swift's 2001 reference epoch.
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            self.positionUpdatedAtUnix = try legacy
                .decodeIfPresent(TimeInterval.self, forKey: .positionUpdatedAt)
                .map { Date(timeIntervalSinceReferenceDate: $0).timeIntervalSince1970 }
        }
    }

    /// What the player is doing, with the integrations' spelling variations collapsed.
    public var playback: RemoteMediaPlaybackState { .init(homeAssistantState: state) }

    /// Whether this report describes an actual piece of media.
    ///
    /// The session's lifetime hangs on this rather than on the playback state: a player that is
    /// paused, or briefly `idle` between tracks, still has something to show.
    public var hasMeaningfulMedia: Bool {
        contentId != nil || title != nil || artist != nil || album != nil || duration != nil
    }

    public var id: String { selection.id }
    public var trackId: String {
        // Metadata is needed when an integration reuses its stream URL across tracks.
        [contentId, title, artist, album].map { value in
            let value = value ?? ""
            return "\(value.utf8.count):\(value)"
        }.joined()
    }

    public func withState(_ state: String) -> Self {
        copy(state: state)
    }

    public func withPosition(_ position: TimeInterval?, updatedAtUnix: TimeInterval?) -> Self {
        copy(position: position, positionUpdatedAtUnix: updatedAtUnix)
    }

    public func withArtwork(_ artwork: RemoteMediaArtworkDescriptor?) -> Self {
        copy(artwork: .some(artwork))
    }

    /// `artwork` is doubly optional so passing `nil` means "unchanged" while `.some(nil)` clears it.
    private func copy(
        state: String? = nil,
        position: TimeInterval?? = nil,
        positionUpdatedAtUnix: TimeInterval?? = nil,
        artwork: RemoteMediaArtworkDescriptor?? = nil
    ) -> Self {
        .init(
            selection: selection,
            deviceName: deviceName,
            deviceClass: deviceClass,
            state: state ?? self.state,
            title: title,
            artist: artist,
            album: album,
            contentId: contentId,
            duration: duration,
            position: position ?? self.position,
            positionUpdatedAtUnix: positionUpdatedAtUnix ?? self.positionUpdatedAtUnix,
            artwork: artwork ?? self.artwork,
            volume: volume,
            isMuted: isMuted,
            features: features
        )
    }
}
