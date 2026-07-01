import Shared
import SwiftUI
import UIKit
@preconcurrency import WebKit
#if targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Status Bar & Toolbar

extension WebViewController {
    func setupStatusBarView() -> UIView {
        let statusBarView = UIView()
        statusBarView.tag = 111
        self.statusBarView = statusBarView

        view.addSubview(statusBarView)
        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            statusBarView.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarView.leftAnchor.constraint(equalTo: view.leftAnchor),
            statusBarView.rightAnchor.constraint(equalTo: view.rightAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])

        return statusBarView
    }

    func openServer(_ server: Server) {
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.open(server: server)
        }
    }

    @objc func customizeToolbar() {
        #if targetEnvironment(macCatalyst)
        view.window?.windowScene?.titlebar?.toolbar?.runCustomizationPalette(nil)
        #endif
    }

    @objc func openServerInSafari() {
        if let url = webView.url {
            guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return
            }
            // Remove external_auth=1 query item from URL
            urlComponents.queryItems = urlComponents.queryItems?.filter { $0.name != "external_auth" }

            if let url = urlComponents.url {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    @objc func copyCurrentSelectedContent() {
        readWebViewSelection { selectedText in
            guard let selectedText, !selectedText.isEmpty else { return }
            UIPasteboard.general.string = selectedText
        }
    }

    @objc func cutCurrentSelectedContent() {
        readWebViewSelection { [weak self] selectedText in
            guard let self, let selectedText, !selectedText.isEmpty else { return }
            UIPasteboard.general.string = selectedText
            injectIntoFocusedElement("")
        }
    }

    @objc func pasteContent() {
        guard let string = UIPasteboard.general.string, !string.isEmpty else { return }
        injectIntoFocusedElement(string)
    }

    private func readWebViewSelection(completion: @escaping (String?) -> Void) {
        webView.evaluateJavaScript(Self.readSelectionJS) { result, error in
            if let error {
                Current.Log.verbose("Read WebView selection failed: \(error.localizedDescription)")
            }
            completion(result as? String)
        }
    }

    private func injectIntoFocusedElement(_ text: String) {
        let script = "(\(Self.injectTextJS))(\(Self.jsStringLiteral(text)));"
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                Current.Log.verbose("Insert text into WebView failed: \(error.localizedDescription)")
            }
        }
    }

    private static func jsStringLiteral(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed]),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }

    private static let readSelectionJS = """
    (function() {
        function fromDocument(doc) {
            try {
                var active = doc.activeElement;
                if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA') &&
                    typeof active.selectionStart === 'number' &&
                    active.selectionStart !== active.selectionEnd) {
                    return active.value.substring(active.selectionStart, active.selectionEnd);
                }
                if (active && active.tagName === 'IFRAME') {
                    try {
                        var innerDoc = active.contentDocument ||
                            (active.contentWindow && active.contentWindow.document);
                        if (innerDoc) {
                            var inner = fromDocument(innerDoc);
                            if (inner) { return inner; }
                        }
                    } catch (error) {}
                }
                var selection = doc.getSelection && doc.getSelection();
                if (selection && selection.toString()) { return selection.toString(); }
            } catch (error) {}
            return '';
        }
        return fromDocument(document);
    })();
    """

    private static let injectTextJS = """
    function(text) {
        function intoDocument(doc) {
            try {
                var active = doc.activeElement;
                if (active && active.tagName === 'IFRAME') {
                    try {
                        var innerDoc = active.contentDocument ||
                            (active.contentWindow && active.contentWindow.document);
                        if (innerDoc && intoDocument(innerDoc)) { return true; }
                    } catch (error) {}
                }
                if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA') &&
                    typeof active.selectionStart === 'number') {
                    var value = active.value;
                    var start = active.selectionStart;
                    var end = active.selectionEnd;
                    active.value = value.slice(0, start) + text + value.slice(end);
                    var caret = start + text.length;
                    active.setSelectionRange(caret, caret);
                    active.dispatchEvent(new Event('input', { bubbles: true }));
                    return true;
                }
                if (active && active.isContentEditable &&
                    doc.execCommand('insertText', false, text)) {
                    return true;
                }
                if (doc.execCommand('insertText', false, text)) { return true; }
            } catch (error) {}
            return false;
        }
        return intoDocument(document);
    }
    """

    @available(iOS 16.0, *)
    @objc func showFindInteraction() {
        // Present the find interaction UI
        if let findInteraction = webView.findInteraction {
            findInteraction.presentFindNavigator(showingReplace: false)
        }
    }
}
