import AVKit
import Foundation
import PromiseKit
import Shared
import UIKit

class CameraStreamHLSViewController: UIViewController, CameraStreamHandler {
    let url: URL
    let playerViewController: AVPlayerViewController
    let promise: Promise<Void>
    var didUpdateState: (CameraStreamHandlerState) -> Void = { _ in }
    private let seal: Resolver<Void>
    private var observationTokens: [NSKeyValueObservation] = []

    enum HLSError: LocalizedError {
        case noPath
        case avPlayer(Error?)

        var errorDescription: String? {
            switch self {
            case .noPath:
                return L10n.Extensions.NotificationContent.Error.Request.hlsUnavailable
            case let .avPlayer(error):
                return error?.localizedDescription ?? L10n.Extensions.NotificationContent.Error.Request.other(-1)
            }
        }
    }

    required convenience init(api: HomeAssistantAPI, response: StreamCameraResponse) throws {
        guard let path = response.hlsPath else {
            throw HLSError.noPath
        }

        let url = api.server.info.connection.activeURL().appendingPathComponent(path)
        self.init(url: url)
    }

    init(url: URL) {
        self.url = url
        self.playerViewController = AVPlayerViewController()
        (self.promise, self.seal) = Promise<Void>.pending()
        super.init(nibName: nil, bundle: nil)

        addChild(playerViewController)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observationTokens.forEach { $0.invalidate() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        playerViewController.didMove(toParent: self)

        setupVideo()
    }

    func pause() {
        playerViewController.player?.pause()
    }

    func play() {
        setupVideo()
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
                aspectRatioConstraint = NSLayoutConstraint.aspectRatioConstraint(
                    on: playerViewController.view,
                    size: size
                )
            }
        }
    }

    private func setupVideo() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)

        let videoPlayer = AVPlayer(url: url)
        playerViewController.player = videoPlayer

        // assume 16:9
        lastSize = CGSize(width: 16, height: 9)

        videoPlayer.play()

        observationTokens.append(videoPlayer.observe(\.status) { [weak self] player, _ in
            Current.Log.error("player status: \(player.status.rawValue) error: \(String(describing: player.error))")
            switch player.status {
            case .readyToPlay:
                // we won't get a rate update on initial play, but it's _happening_!
                // the system UI for loading/spinning will take over from here.
                self?.didUpdateState(.playing)
                self?.seal.fulfill(())
            case .failed:
                self?.seal.reject(HLSError.avPlayer(player.error))
            case .unknown:
                break
            @unknown default:
                break
            }
        })

        observationTokens.append(videoPlayer.observe(\.rate) { [weak self] player, _ in
            // these still fire if the user manually pauses/plays in the video player itself
            self?.didUpdateState(player.rate > 0 ? .playing : .paused)
        })

        observationTokens.append(videoPlayer.observe(\AVPlayer.currentItem?.tracks) { [weak self] item, _ in
            let sizes = item.currentItem?
                .tracks
                .compactMap({ $0.assetTrack?.naturalSize })
                .filter {
                    // hls streams occasionally bounce between (0, 0); (1, 1); and the real size
                    $0.width > 1 && $0.height > 1
                }

            self?.lastSize = sizes?.first
        })
    }
}
