import UIKit
import Social
import Shared
import PromiseKit
import CoreServices

@objc(HAShareViewController)
class ShareViewController: SLComposeServiceViewController {
    init() {
        super.init(nibName: nil, bundle: nil)

        if let tokenInfo = Current.settingsStore.tokenInfo {
            Current.tokenManager = TokenManager(tokenInfo: tokenInfo)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum EventError: LocalizedError {
        case invalidExtensionContext
    }

    private func event() -> Promise<(eventType: String, eventData: [String: String])> {
        guard let extensionContext = extensionContext else {
            return .init(error: EventError.invalidExtensionContext)
        }

        let entered: Guarantee<String> = .value(contentText)
        let url: Guarantee<URL?> = extensionContext.inputItemAttachments(for: .url).map { $0.first }
        let text: Guarantee<String?> = extensionContext.inputItemAttachments(for: .text).map { values in
            if values.isEmpty {
                return nil
            } else {
                return values.joined(separator: "\n")
            }
        }

        return firstly {
            when(fulfilled: entered, url, text)
        }.map { entered, url, text in
            HomeAssistantAPI.shareEvent(
                entered: entered,
                url: url,
                text: text
            )
        }
    }

    override func loadPreviewView() -> UIView! {
        nil
    }

    override func didSelectPost() {
        Current.Log.info("starting to post")

        firstly {
            when(fulfilled: Current.api, event())
        }.then { api, event -> Promise<Void> in
            Current.Log.verbose("starting request")
            return api.CreateEvent(eventType: event.eventType, eventData: event.eventData)
        }.done { [extensionContext] in
            Current.Log.info("succeeded with post")
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }.catch { [weak self] error in
            Current.Log.error("failed to post: \(error)")
            let alert = UIAlertController(
                title: L10n.ShareExtension.Error.title,
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: { _ in
                self?.extensionContext?.cancelRequest(withError: error)
            }))
            self?.present(alert, animated: true, completion: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = L10n.ShareExtension.enteredPlaceholder
    }
}
