import Foundation
import PromiseKit
import Shared
import UserNotifications
import WatchKit

final class NotificationSubControllerMedia: NotificationSubController {
    enum MediaType {
        case playable(URL)
        case image(UIImage)
    }

    let api: HomeAssistantAPI
    let media: MediaType
    let endSecurityScopeURL: URL?

    convenience init?(api: HomeAssistantAPI, notification: UNNotification) {
        guard let url = notification.request.content.attachments.first?.url else {
            return nil
        }

        self.init(api: api, url: url)
    }

    init?(api: HomeAssistantAPI, url: URL) {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        let data: Data

        do {
            // FB9096214 watchOS will give us a url which fails security scoped access and errors with
            // Error Domain=NSCocoaErrorDomain Code=257
            // so we unfortunately have to pretend like no attachment existed if we can't _read_ it
            data = try Data(contentsOf: url, options: .alwaysMapped)
        } catch {
            Current.Log.error("failed to open data: \(error) security scope happened \(didStartSecurityScope)")
            return nil
        }

        Current.Log.info("creating with url \(url) data size \(data.count)")

        self.api = api

        if let image = UIImage(data: data) {
            self.media = .image(image)
        } else {
            self.media = .playable(url)
        }

        if didStartSecurityScope {
            self.endSecurityScopeURL = url
        } else {
            self.endSecurityScopeURL = nil
        }
    }

    deinit {
        endSecurityScopeURL?.stopAccessingSecurityScopedResource()
    }

    func start(with elements: NotificationElements) -> Promise<Void> {
        switch media {
        case let .playable(url):
            elements.movie.setHidden(false)
            elements.movie.setLoops(true)
            elements.movie.setMovieURL(url)
            elements.movie.play()
        case let .image(image):
            elements.image.setHidden(false)
            elements.image.setImage(image)
        }

        return .value(())
    }

    func stop() {}
}
