import UniformTypeIdentifiers
import UIKit

/// Presents the system file picker for `WKWebView` file inputs and reports the chosen URLs.
///
/// On Mac Catalyst this surfaces as `NSOpenPanel`. The presenter retains itself for the lifetime
/// of the picker so the completion handler still runs if the web view is released.
final class WebViewOpenPanelPresenter: NSObject, UIDocumentPickerDelegate {
    private var completion: (([URL]?) -> Void)?
    private var selfRetain: WebViewOpenPanelPresenter?

    func present(
        from viewController: UIViewController,
        sourceView: UIView,
        allowsMultipleSelection: Bool,
        allowsDirectories: Bool,
        requestedTypes: [UTType],
        completion: @escaping ([URL]?) -> Void
    ) {
        finish(nil)

        var types = WebViewOpenPanelContentTypes.contentTypes(requested: requestedTypes)
        if allowsDirectories, !types.contains(.folder) {
            types.append(.folder)
        }

        self.completion = completion
        selfRetain = self

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.popoverPresentationController?.sourceView = sourceView
        picker.popoverPresentationController?.sourceRect = CGRect(
            x: sourceView.bounds.midX,
            y: sourceView.bounds.midY,
            width: 0,
            height: 0
        )

        viewController.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(nil)
    }

    deinit {
        completion?(nil)
    }

    private func finish(_ urls: [URL]?) {
        let completion = completion
        self.completion = nil
        selfRetain = nil
        completion?(urls)
    }
}
