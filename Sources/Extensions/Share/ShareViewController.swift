import CoreServices
import PromiseKit
import Shared
import Social
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@objc(HAShareViewController)
class ShareViewController: SLComposeServiceViewController {
    enum EventError: LocalizedError {
        case invalidExtensionContext
    }

    private func event(api: HomeAssistantAPI) -> Promise<(eventType: String, eventData: [String: String])> {
        guard let extensionContext else {
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

    // The Mac compose sheet has no preview and no configuration rows to customise.
    #if os(iOS)
    override func loadPreviewView() -> UIView! {
        nil
    }
    #endif

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
            self?.showFailure(error)
        }
    }

    /// Tells the user the event was not sent, then hands the request back as cancelled.
    private func showFailure(_ error: Error) {
        #if os(macOS)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.ShareExtension.Error.title
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: L10n.okLabel)
        let cancelRequest: (NSApplication.ModalResponse) -> Void = { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: error)
        }
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: cancelRequest)
        } else {
            cancelRequest(alert.runModal())
        }
        #else
        let alert = UIAlertController(
            title: L10n.ShareExtension.Error.title,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: error)
        }))
        present(alert, animated: true, completion: nil)
        #endif
    }

    #if os(iOS)
    override func configurationItems() -> [Any]! {
        []
    }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = L10n.ShareExtension.enteredPlaceholder
    }
}
