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

    private func event() -> Promise<(eventType: String, eventData: [String: String])> {
        let extensionItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []

        let entered: Guarantee<String> = .value(contentText)

        let url: Guarantee<URL?> = Guarantee { seal in
            let attachments = extensionItems
                .flatMap { $0.attachments ?? [] }
                .filter { $0.hasItemConformingToTypeIdentifier(kUTTypeURL as String) }

            if let first = attachments.first {
                first.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { urlData, _ in
                    let url = urlData as? URL
                    Current.Log.info("got url: \(String(describing: url)) from \(type(of: urlData))")
                    seal(url)
                }
            } else {
                Current.Log.info("no attachments contain URLs")
                seal(nil)
            }
        }

        return firstly {
            when(fulfilled: entered, url)
        }.map { entered, url in
            HomeAssistantAPI.shareEvent(
                entered: entered,
                url: url,
                text: nil
            )
        }
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func loadPreviewView() -> UIView! {
        nil
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.

        Current.Log.info("starting to post")

        firstly {
            when(fulfilled: HomeAssistantAPI.authenticatedAPIPromise, event())
        }.then { api, event -> Promise<Void> in
            Current.Log.verbose("starting request")
            return api.CreateEvent(eventType: event.eventType, eventData: event.eventData)
        }.ensure { [extensionContext] in
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return [
            with(SLComposeSheetConfigurationItem()) {
                $0?.title = "View Event"
                $0?.tapHandler = { [weak self] in
                    self?.pushExampleViewController()
                }
            }
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        placeholder = "text"

        
    }

    private func pushExampleViewController() {
        class ExampleViewController: UIViewController {
            let display: Promise<String>
            init(display: Promise<String>) {
                self.display = display
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override func viewDidLoad() {
                super.viewDidLoad()

                let textView = UITextView()
                view.addSubview(textView)
                textView.frame = view.bounds

                display.done { textView.text = $0 }
            }
        }

        pushConfigurationViewController(ExampleViewController(display: event().map { event in
            let eventDataStrings = event.eventData.map { $0 + ": " + $1 }.sorted()
            let indentation = "\n    "

            return """
            - platform: event
              event_type: \(event.eventType)
              event_data:
                \(eventDataStrings.joined(separator: indentation))
            """
        }))
    }
}
