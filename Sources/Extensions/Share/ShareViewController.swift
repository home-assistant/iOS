import CoreServices
import PromiseKit
import Shared
import Social
import UIKit

@objc(HAShareViewController)
class ShareViewController: SLComposeServiceViewController {
    enum EventError: LocalizedError {
        case invalidExtensionContext
    }

    private func event(api: HomeAssistantAPI) -> Promise<(eventType: String, eventData: [String: String])> {
        guard let extensionContext = extensionContext else {
            return .init(error: EventError.invalidExtensionContext)
        }

        let entered: Guarantee<String> = .value(contentText)
        let url: Guarantee<URL?> = extensionContext.inputItemAttachments(for: .url).map(\.first)
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
            api.shareEvent(
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

        firstly { () -> Promise<Void> in
            Current.Log.verbose("starting request")
            return when(fulfilled: Current.apis.map { api -> Promise<Void> in
                firstly {
                    event(api: api)
                }.then { event in
                    api.CreateEvent(eventType: event.eventType, eventData: event.eventData)
                }
            }).asVoid()
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
        []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = L10n.ShareExtension.enteredPlaceholder
    }
}
