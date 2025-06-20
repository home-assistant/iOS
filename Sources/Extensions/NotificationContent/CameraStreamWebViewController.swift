import Alamofire
import UserNotificationsUI
import Foundation
import PromiseKit
import Shared
import UIKit
import WebKit

class CameraStreamWebViewController: UIViewController, NotificationCategory {
    var webView: WKWebView!

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        super.init(nibName: nil, bundle: nil)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = false


        let userContentController = WKUserContentController()
        let safeScriptMessageHandler = SafeScriptMessageHandler(delegate: self)
        userContentController.add(safeScriptMessageHandler, name: "getExternalAuth")
        userContentController.add(safeScriptMessageHandler, name: "revokeExternalAuth")
        userContentController.add(safeScriptMessageHandler, name: "logError")

        guard let wsBridgeJSPath = Bundle.main.path(forResource: "WebSocketBridge", ofType: "js"),
              let wsBridgeJS = try? String(contentsOfFile: wsBridgeJSPath) else {
            fatalError("Couldn't load WebSocketBridge.js for injection to WKWebView!")
        }

        userContentController.addUserScript(WKUserScript(
            source: wsBridgeJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))

        userContentController.addUserScript(.init(
            source: """
                window.addEventListener("error", (e) => {
                    window.webkit.messageHandlers.logError.postMessage({
                        "message": JSON.stringify(e.message),
                        "filename": JSON.stringify(e.filename),
                        "lineno": JSON.stringify(e.lineno),
                        "colno": JSON.stringify(e.colno),
                    });
                });
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        config.userContentController = userContentController
        config.applicationNameForUserAgent = HomeAssistantAPI.applicationNameForUserAgent

        self.webView = WKWebView(frame: .zero, configuration: config)
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
//        webView.load(URLRequest(url: URL(string: "http://192.168.0.157:1984/stream.html?src=doorbell-unifi")!))
        webView.load(URLRequest(url: URL(string: "http://192.168.0.133:8123?external_auth=1")!))
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

extension CameraStreamWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any] else {
            Current.Log.error("received message for \(message.name) but of type: \(type(of: message.body))")
            return
        }

        Current.Log.verbose("message \(message.body)".replacingOccurrences(of: "\n", with: " "))

        switch WKUserContentControllerMessage(rawValue: message.name) {
        case .getExternalAuth:
            guard let callbackName = messageBody["callback"] else { return }
            let force = messageBody["force"] as? Bool ?? false

            Current.Log.verbose("getExternalAuth called, forced: \(force)")

            firstly {
                Current.api(for: Current.servers.all.first!)?.tokenManager
                    .authDictionaryForWebView(forceRefresh: force) ??
                    .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
            }.done { dictionary in
                let jsonData = try? JSONSerialization.data(withJSONObject: dictionary)
                if let jsonString = String(data: jsonData!, encoding: .utf8) {
                    let script = "\(callbackName)(true, \(jsonString))"
                    self.webView.evaluateJavaScript(script, completionHandler: { result, error in
                        if let error {
                            Current.Log.error("Failed to trigger getExternalAuth callback: \(error)")
                        }
                        Current.Log.verbose("Success on getExternalAuth callback: \(String(describing: result))")
                    })
                }
            }.catch { error in
                self.webView.evaluateJavaScript("\(callbackName)(false, 'Token unavailable')")
                Current.Log.error("Failed to authenticate webview: \(error)")
            }
        case .revokeExternalAuth:
            break
        case .logError:
            break
        default:
            Current.Log.error("unknown message: \(message.name)")
        }
    }
}
