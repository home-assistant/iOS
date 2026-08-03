import AVFoundation
import Foundation
import Shared

/// Loads an HLS asset's data through the server's own authenticated networking.
///
/// AVFoundation never surfaces the client certificate challenge to the app (a years-old limitation,
/// see `CameraStreamHLSViewController` on iOS) and knows nothing about the self-signed certificates
/// the user trusted in the app, so on those servers the player can't fetch the playlist or segments
/// by itself. Asking the asset for exclusive client URL loading routes every request here instead,
/// where the app's session presents the certificate and applies the stored exceptions.
final class WatchCameraHLSResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let api: HomeAssistantAPI

    init(api: HomeAssistantAPI) {
        self.api = api
        super.init()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        // Not handled here (same as iOS): byte-range requests and content information — the live
        // playlists and segments the camera stream serves are fetched whole.
        api.manager.streamRequest(loadingRequest.request).validate().responseStream(stream: { stream in
            switch stream.event {
            case let .complete(completion):
                if let error = completion.error {
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
