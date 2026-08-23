#if targetEnvironment(macCatalyst)
import UniformTypeIdentifiers
import WebKit

extension WebViewController {
    /// Mac Catalyst does not present a file picker for `<input type="file">` unless this
    /// `WKUIDelegate` method is implemented. Safari's `NSOpenPanel` allows FLAC; the default
    /// Catalyst picker does not, so allowed types are widened when WebKit's list is empty or
    /// an audio subset that omits FLAC.
    @available(iOS 18.4, *)
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        if presentedViewController != nil {
            Current.Log.error("attempted to present an open panel when already presenting, bailing")
            completionHandler(nil)
            return
        }

        let requestedTypes = WebViewOpenPanelContentTypes.requestedTypes(from: parameters)
        let presenter = WebViewOpenPanelPresenter()
        presenter.present(
            from: self,
            sourceView: webView,
            allowsMultipleSelection: parameters.allowsMultipleSelection,
            allowsDirectories: parameters.allowsDirectories,
            requestedTypes: requestedTypes,
            completion: completionHandler
        )
    }
}
#endif
