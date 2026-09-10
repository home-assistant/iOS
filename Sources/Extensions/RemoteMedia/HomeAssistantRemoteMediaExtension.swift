import ExtensionFoundation
import NowPlaying

@main
struct HomeAssistantRemoteMediaExtension: RemoteMediaSessionExtension {
    var configuration: RemoteMediaSessionExtensionConfiguration<Self> {
        .init(extension: self)
    }

    func session(_ attributes: RemoteMediaSessionAttributes) async throws -> HomeAssistantRemoteMediaSession {
        RemoteMediaLog.logger.info("Creating session")
        let session = HomeAssistantRemoteMediaSession(attributes: attributes)
        // The framework attaches the session's push token after this returns, so observation has to
        // begin outside the initializer.
        session.startObservingPushToken()
        return session
    }
}
