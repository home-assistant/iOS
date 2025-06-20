import Alamofire
import UserNotificationsUI
import Foundation
import PromiseKit
import Shared
import UIKit
import WebKit

class CameraStreamWebViewController: UIViewController, NotificationCategory {
    let webView: WKWebView

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        self.webView = WKWebView()
        super.init(nibName: nil, bundle: nil)
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.allowsAirPlayForMediaPlayback = false
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        webView.configuration.allowsPictureInPictureMediaPlayback = false
        webView.scrollView.bounces = false
    }

    ///

    func start() -> Promise<Void> {
        .value(())
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        .none
    }

    var mediaPlayPauseButtonFrame: CGRect? {
        nil
    }

    func mediaPlay() {
        //
    }

    func mediaPause() {
        //
    }


    ///

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.widthAnchor.constraint(equalTo: view.widthAnchor),
            webView.heightAnchor.constraint(equalToConstant: 400)
        ])

#if DEBUG
        let webViewLabel = UILabel()
        webViewLabel.text = "WebView"
        webViewLabel.backgroundColor = .black
        webViewLabel.textColor = .white
        webViewLabel.font = UIFont.boldSystemFont(ofSize: 14)
        webViewLabel.textAlignment = .center
        webViewLabel.layer.cornerRadius = 4
        webViewLabel.layer.masksToBounds = true
        webViewLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webViewLabel)
        NSLayoutConstraint.activate([
            webViewLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            webViewLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            webViewLabel.widthAnchor.constraint(equalToConstant: 90),
            webViewLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
#endif

        setupStreamer()
    }

    private func setupStreamer() {
        webView.navigationDelegate = self
        webView.load(URLRequest(url: URL(string: "http://192.168.0.157:1984/stream.html?src=doorbell-unifi")!))
        runHack()
    }

    func pause() { }

    func play() { }

    private var playTimer: Timer?

    private func startPlayTimer() {
        playTimer?.invalidate()
        playTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.forcePlayVideo()
        }
    }

    private func stopPlayTimer() {
        playTimer?.invalidate()
        playTimer = nil
    }

    private func forcePlayVideo() {
        let js = """
        (function() {
            var videos = document.getElementsByTagName('video');
            for (var i = 0; i < videos.length; i++) {
                var video = videos[i];
                    video.muted = true;
                    video.autoplay = true;
                    video.playsInline = true;
                    video.play();
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func runHack() {
        let js = """
        (function() {
            function patchVideo(video) {
                if (video._hass_patched) return;
                video._hass_patched = true;
                video.muted = true;
                video.autoplay = true;
                video.playsInline = true;
                video.addEventListener('pause', function() { this.play(); });
            }
            function patchAllVideos() {
                var videos = document.getElementsByTagName('video');
                for (var i = 0; i < videos.length; i++) {
                    patchVideo(videos[i]);
                }
            }
            patchAllVideos();
            var observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'childList') {
                        mutation.addedNodes.forEach(function(node) {
                            if (node.tagName === 'VIDEO') {
                                patchVideo(node);
                            } else if (node.querySelectorAll) {
                                var vids = node.querySelectorAll('video');
                                vids.forEach(patchVideo);
                            }
                        });
                    }
                });
                patchAllVideos();
            });
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPlayTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayTimer()
    }
}

extension CameraStreamWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        runHack()
    }
}
