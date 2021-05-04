import Foundation
import PromiseKit
import UserNotifications
import WatchKit

final class NotificationSubControllerMedia: NotificationSubController {
    enum MediaType {
        case playable(URL)
        case image(UIImage)
    }

    let media: MediaType
    let endSecurityScopeURL: URL?

    convenience init?(notification: UNNotification) {
        guard let url = notification.request.content.attachments.first?.url else {
            return nil
        }

        self.init(url: url)
    }

    init?(url: URL) {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()

        if let image = UIImage(contentsOfFile: url.path) {
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
