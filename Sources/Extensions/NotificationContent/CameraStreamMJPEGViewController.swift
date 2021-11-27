import Alamofire
import Foundation
import PromiseKit
import Shared
import UIKit

class CameraStreamMJPEGViewController: UIViewController, CameraStreamHandler {
    let api: HomeAssistantAPI
    let response: StreamCameraResponse
    let imageView: UIImageView
    let streamer: MJPEGStreamer
    let promise: Promise<Void>
    var didUpdateState: (CameraStreamHandlerState) -> Void = { _ in }
    private let seal: Resolver<Void>

    enum MJPEGError: LocalizedError {
        case noPath
        case networkError(path: String, error: Error?)

        var errorDescription: String? {
            switch self {
            case .noPath:
                return L10n.Extensions.NotificationContent.Error.Request.authFailed
            case let .networkError(path, error):
                if let error = error as? AFError, let responseCode = error.responseCode {
                    switch responseCode {
                    case 401:
                        return L10n.Extensions.NotificationContent.Error.Request.authFailed
                    case 404:
                        return L10n.Extensions.NotificationContent.Error.Request.entityNotFound(path)
                    default:
                        return L10n.Extensions.NotificationContent.Error.Request.other(responseCode)
                    }
                }

                return error?.localizedDescription ?? L10n.Extensions.NotificationContent.Error.Request.other(-1)
            }
        }
    }

    required init(api: HomeAssistantAPI, response: StreamCameraResponse) throws {
        guard response.mjpegPath != nil else {
            throw MJPEGError.noPath
        }

        self.api = api
        self.response = response
        self.streamer = api.VideoStreamer()
        self.imageView = UIImageView()
        (self.promise, self.seal) = Promise<Void>.pending()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        setupStreamer()
    }

    func pause() {
        streamer.cancel()
        didUpdateState(.paused)
    }

    func play() {
        if !streamer.isActive {
            setupStreamer()
        }
    }

    private var aspectRatioConstraint: NSLayoutConstraint? {
        willSet {
            aspectRatioConstraint?.isActive = false
        }
        didSet {
            aspectRatioConstraint?.isActive = true
        }
    }

    private var lastSize: CGSize? {
        didSet {
            if oldValue != lastSize, let size = lastSize {
                aspectRatioConstraint = NSLayoutConstraint.aspectRatioConstraint(on: imageView, size: size)
            }
        }
    }

    private func setupStreamer() {
        guard let path = response.mjpegPath else {
            fatalError("we checked for a non-nil path on init, this should not be possible")
        }

        let url = api.server.info.connection.activeURL().appendingPathComponent(path)

        // assume 16:9
        lastSize = CGSize(width: 16, height: 9)

        streamer.streamImages(fromURL: url) { [weak self, imageView] image, error in
            guard let image = image else {
                self?.seal.reject(MJPEGError.networkError(path: path, error: error))
                return
            }

            imageView.image = image
            self?.seal.fulfill(())
            self?.lastSize = image.size
            self?.didUpdateState(.playing)
        }
    }
}
