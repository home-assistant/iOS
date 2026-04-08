import PromiseKit
import Shared
import UIKit
import WebKit

protocol OnboardingAuthLoginViewController: UIViewController {
    var promise: Promise<URL> { get }
    init(authDetails: OnboardingAuthDetails)
}

class OnboardingAuthLoginViewControllerImpl: UIViewController, OnboardingAuthLoginViewController, WKNavigationDelegate {
    let authDetails: OnboardingAuthDetails
    let promise: Promise<URL>
    private let resolver: Resolver<URL>
    private var webViewBottomConstraint: NSLayoutConstraint?
    private var keyboardScrollWorkItem: DispatchWorkItem?
    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = HomeAssistantAPI.applicationNameForUserAgent

        return WKWebView(frame: .zero, configuration: configuration)
    }()

    required init(authDetails: OnboardingAuthDetails) {
        (self.promise, self.resolver) = Promise<URL>.pending()
        self.authDetails = authDetails
        super.init(nibName: nil, bundle: nil)

        title = authDetails.url.host

        isModalInPresentation = true

        let appearance = with(UINavigationBarAppearance()) {
            $0.configureWithOpaqueBackground()
        }

        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.compactScrollEdgeAppearance = appearance

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        keyboardScrollWorkItem?.cancel()
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    @objc private func cancel() {
        resolver.reject(PMKError.cancelled)
    }

    @objc private func refresh() {
        webView.load(.init(url: authDetails.url))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self

        setContentScrollView(webView.scrollView)

        view.backgroundColor = .systemBackground
        edgesForExtendedLayout = []

        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        let bottomConstraint = WebViewController.makeWebViewBottomConstraint(for: webView, in: view)
        webViewBottomConstraint = bottomConstraint
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            bottomConstraint,
        ])

        setupKeyboardAvoidance()
        refresh()
    }

    private func setupKeyboardAvoidance() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardDidChangeFrame(_:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        let overlapHeight = WebViewKeyboardAvoidance.keyboardOverlapHeight(in: view, notification: notification)
        let duration = WebViewKeyboardAvoidance.keyboardAnimationDuration(from: notification)
        let options = WebViewKeyboardAvoidance.keyboardAnimationOptions(from: notification)

        webViewBottomConstraint?.constant = -overlapHeight

        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) { [weak self] in
            self?.view.layoutIfNeeded()
        }

        keyboardScrollWorkItem?.cancel()
        guard overlapHeight > 0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.webView.scrollFocusedElementIntoView()
        }
        keyboardScrollWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    @objc private func handleKeyboardDidChangeFrame(_ notification: Notification) {
        guard WebViewKeyboardAvoidance.keyboardOverlapHeight(in: view, notification: notification) > 0 else { return }
        webView.scrollFocusedElementIntoView()
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Handle client certificate challenge (mTLS)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            handleClientCertificateChallenge(challenge, completionHandler: completionHandler)
            return
        }

        // Handle server trust (including self-signed certs)
        let result = authDetails.exceptions.evaluate(challenge)
        completionHandler(result.0, result.1)
    }

    private func handleClientCertificateChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        #if !os(watchOS)
        guard let clientCertificate = authDetails.clientCertificate else {
            Current.Log.error("Client certificate required but none configured")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        do {
            let credential = try ClientCertificateManager.shared.urlCredential(for: clientCertificate)
            Current.Log.info("Using client certificate: \(clientCertificate.displayName)")
            completionHandler(.useCredential, credential)
        } catch {
            Current.Log.error("Failed to get credential for client certificate: \(error)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
        #else
        completionHandler(.cancelAuthenticationChallenge, nil)
        #endif
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resolver.reject(error)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url, url.scheme?.hasPrefix("homeassistant") == true {
            resolver.fulfill(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

#if DEBUG
extension OnboardingAuthLoginViewControllerImpl {
    var webViewForTests: WKWebView {
        webView
    }
}
#endif
