import Alamofire
import AVFoundation
import Foundation
import Shared

/// Loads an HLS asset's requests through the app's own session instead of letting AVFoundation
/// fetch them itself.
///
/// AVFoundation does its networking outside `URLSession` delegates, so a server that asks for a
/// client certificate — or one reached with a security exception — never gets one and the stream
/// simply fails to load. Routing every request through `api.manager`, which already carries the
/// certificate and the exceptions, is how the notification extension's player has always handled
/// this; the in-app player needs the same treatment.
///
/// The asset does not retain its resource loader delegate, so whoever builds the player has to keep
/// this alive for as long as it plays.
final class CameraHLSAssetLoader: NSObject {
    /// The options that make AVFoundation hand its requests to the delegate at all. Taken from
    /// WebKit, which needs the same thing: without them the playlists load but the media segments
    /// don't, because no authentication challenge is ever raised.
    /// See https://github.com/WebKit/WebKit — `MediaPlayerPrivateAVFoundationObjC.mm`.
    private static let customLoadingOptions: [String: Any] = [
        "AVURLAssetUseClientURLLoadingExclusively": true,
        "AVURLAssetRequiresCustomURLLoadingKey": true,
    ]

    private let api: HomeAssistantAPI

    init(api: HomeAssistantAPI) {
        self.api = api
        super.init()
    }

    /// Builds the asset for `url`, taking over its loading only when the server needs credentials
    /// AVFoundation cannot present on its own. Returns `nil` when nothing needs to be taken over,
    /// so the caller keeps the plain asset and this loader is not needed.
    static func asset(for url: URL, api: HomeAssistantAPI) -> (asset: AVURLAsset, loader: CameraHLSAssetLoader?) {
        guard needsCustomLoading(url: url, connection: api.server.info.connection) else {
            return (AVURLAsset(url: url), nil)
        }

        let asset = AVURLAsset(url: url, options: customLoadingOptions)
        let loader = CameraHLSAssetLoader(api: api)
        asset.resourceLoader.setDelegate(loader, queue: .main)
        return (asset, loader)
    }

    /// Whether AVFoundation's own networking would fail to reach this server. It cannot present a
    /// client certificate, and it never raises the trust challenge a security exception answers, so
    /// either one means the app has to fetch the stream itself. A local file needs neither.
    static func needsCustomLoading(url: URL, connection: ConnectionInfo) -> Bool {
        guard !url.isFileURL else { return false }
        return connection.securityExceptions.hasExceptions || connection.clientCertificate != nil
    }
}

extension CameraHLSAssetLoader: AVAssetResourceLoaderDelegate {
    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        api.manager.streamRequest(loadingRequest.request).validate().responseStream(stream: { stream in
            switch stream.event {
            case let .complete(completion):
                if let error = completion.error {
                    Current.Log.error("HLS asset request failed: \(error.localizedDescription)")
                    loadingRequest.finishLoading(with: error)
                } else {
                    loadingRequest.finishLoading()
                }
            case let .stream(.success(data)):
                loadingRequest.dataRequest?.respond(with: data)
            }
        })

        return true
    }
}
