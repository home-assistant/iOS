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
    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    required init(authDetails: OnboardingAuthDetails) {
        (self.promise, self.resolver) = Promise<URL>.pending()
        self.authDetails = authDetails
        super.init(nibName: nil, bundle: nil)

        title = authDetails.url.host

        if #available(iOS 13, *) {
            isModalInPresentation = true

            let appearance = with(UINavigationBarAppearance()) {
                $0.configureWithOpaqueBackground()
            }

            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
            navigationItem.compactAppearance = appearance

            if #available(iOS 15, *) {
                navigationItem.compactScrollEdgeAppearance = appearance
            }
        }

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func cancel() {
        resolver.reject(PMKError.cancelled)
    }

    @objc private func refresh() {
        webView.load(.init(url: authDetails.url))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self

        if #available(iOS 15, *) {
            setContentScrollView(webView.scrollView)
        }

        if #available(iOS 13, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        edgesForExtendedLayout = []

        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        refresh()
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let result = authDetails.exceptions.evaluate(challenge)
        completionHandler(result.0, result.1)
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
