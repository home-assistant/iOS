import UIKit
import Social
import Shared
import PromiseKit

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

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.

        let extensionItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []

        let entered: Guarantee<String> = .value(contentText)

        let url: Guarantee<URL?> = Guarantee { seal in
            let attachments = extensionItems
                .flatMap { $0.attachments ?? [] }
                .filter { $0.hasItemConformingToTypeIdentifier(kUTTypeURL as String) }

            if let first = attachments.first {
                first.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { urlData, _ in
                    let url = urlData as? URL
                    Current.Log.info("got url: \(url) from \(type(of: urlData))")
                    seal(url)
                }
            } else {
                Current.Log.info("no attachments contain URLs")
                seal(nil)
            }
        }

        Current.Log.info("starting to post")

        firstly {
            when(fulfilled: HomeAssistantAPI.authenticatedAPIPromise, entered, url)
        }.then { api, entered, url -> Promise<Void> in
            let eventInfo = HomeAssistantAPI.shareEvent(
                entered: entered,
                url: url,
                text: nil
            )

            Current.Log.verbose("starting request")

            return api.CreateEvent(eventType: eventInfo.eventType, eventData: eventInfo.eventData)
        }.ensure { [extensionContext] in
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

}
