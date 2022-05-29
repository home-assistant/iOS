import AuthenticationServices
import Foundation
import PromiseKit
import Shared
import WebKit

protocol OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String>
}

class OnboardingAuthLoginViewController: UIViewController, WKNavigationDelegate {
    let authDetails: OnboardingAuthDetails
    let promise: Promise<URL>
    private let resolver: Resolver<URL>

    init(authDetails: OnboardingAuthDetails) {
        (self.promise, self.resolver) = Promise<URL>.pending()
        self.authDetails = authDetails
        super.init(nibName: nil, bundle: nil)

        title = "Login"

        if #available(iOS 13, *) {
            isModalInPresentation = true

            let appearance = with(UINavigationBarAppearance()) {
                $0.configureWithDefaultBackground()
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
        webView?.load(.init(url: authDetails.url))
    }

    private var webView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView = webView
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

class OnboardingAuthLoginImpl: OnboardingAuthLogin {
    var authenticationSessionClass: ASWebAuthenticationSession.Type = ASWebAuthenticationSession.self
    var macPresentTimer: Timer? {
        didSet {
            if oldValue != macPresentTimer {
                oldValue?.invalidate()
            }
        }
    }

    enum OnboardingAuthLoginError: Error {
        case invalidURL
    }

    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String> {
        Current.Log.verbose(authDetails.url)

        let controller = OnboardingAuthLoginViewController(authDetails: authDetails)
        let navigationController = UINavigationController(rootViewController: controller)
        sender.present(navigationController, animated: true, completion: nil)

        return controller.promise.map { url in
            if let code = url.queryItems?["code"] {
                return code
            } else {
                throw OnboardingAuthLoginError.invalidURL
            }
        }.ensureThen {
            Guarantee<Void> { seal in
                navigationController.dismiss(animated: true, completion: {
                    seal(())
                })
            }
        }
    }
}
