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
        webView.evaluateJavaScript(script) { result, error in
            if let error {
                Current.Log.verbose("Insert text into WebView failed: \(error.localizedDescription)")
            } else if (result as? Bool) != true {
                Current.Log.verbose("Insert text into WebView found no focused editable element")
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
        function deepActive(root, roots) {
            var el = root && root.activeElement;
            while (el) {
                if (el.tagName === 'IFRAME' || el.tagName === 'FRAME') {
                    try {
                        var idoc = el.contentDocument ||
                            (el.contentWindow && el.contentWindow.document);
                        if (!idoc) { return { el: el, root: root, roots: roots }; }
                        var inner = idoc.activeElement;
                        if (inner && inner !== idoc.body) {
                            root = idoc; roots = []; el = inner; continue;
                        }
                        return { el: idoc.activeElement || idoc.body, root: idoc, roots: [] };
                    } catch (error) {
                        return { el: el, root: root, roots: roots };
                    }
                } else if (el.shadowRoot) {
                    var next = el.shadowRoot.activeElement;
                    if (next) {
                        roots.push(el.shadowRoot);
                        root = el.shadowRoot; el = next; continue;
                    }
                    break;
                }
                break;
            }
            return { el: el, root: root, roots: roots };
        }
        function docOf(root) {
            if (!root) { return document; }
            if (root.nodeType === 9) { return root; }
            return root.ownerDocument || document;
        }
        function rootsForNode(node) {
            var out = [];
            var current = node;
            while (current) {
                var r = current.getRootNode ? current.getRootNode() : null;
                if (!r || r.nodeType === 9) { break; }
                if (r.host) { out.push(r); current = r.host; } else { break; }
            }
            return out;
        }
        function composedText(sel, roots, doc) {
            if (!sel || typeof sel.getComposedRanges !== 'function') { return ''; }
            var ranges = null;
            try { ranges = sel.getComposedRanges({ shadowRoots: roots || [] }); }
            catch (error) {
                try { ranges = sel.getComposedRanges.apply(sel, roots || []); }
                catch (error2) { ranges = null; }
            }
            if (!ranges || !ranges.length) { return ''; }
            var sr = ranges[0];
            try {
                var live = doc.createRange();
                live.setStart(sr.startContainer, sr.startOffset);
                live.setEnd(sr.endContainer, sr.endOffset);
                var composed = live.toString();
                if (composed) { return composed; }
            } catch (error3) {}
            return '';
        }
        function selectionText(root, roots) {
            try {
                var doc = docOf(root);
                var win = doc.defaultView || window;
                var sel = (win.getSelection && win.getSelection()) ||
                    (doc.getSelection && doc.getSelection());
                if (!sel) { return ''; }
                var text = sel.toString();
                if (text) { return text; }
                var anchorRoots = [];
                try {
                    var node = sel.anchorNode || sel.focusNode;
                    if (node) { anchorRoots = rootsForNode(node); }
                } catch (errorA) {}
                var useRoots = (anchorRoots && anchorRoots.length) ? anchorRoots : (roots || []);
                return composedText(sel, useRoots, doc);
            } catch (error) {}
            return '';
        }
        try {
            var found = deepActive(document, []);
            var el = found.el;
            if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') &&
                typeof el.selectionStart === 'number' &&
                el.selectionStart !== el.selectionEnd) {
                return el.value.substring(el.selectionStart, el.selectionEnd);
            }
            var scoped = selectionText(found.root, found.roots);
            if (scoped) { return scoped; }
            return selectionText(document, []);
        } catch (error) {}
        return '';
    })();
    """

    private static let injectTextJS = """
    function(text) {
        if (text == null) { text = ''; }
        function deepActive(root) {
            var el = root && root.activeElement;
            while (el) {
                if (el.tagName === 'IFRAME' || el.tagName === 'FRAME') {
                    try {
                        var idoc = el.contentDocument ||
                            (el.contentWindow && el.contentWindow.document);
                        if (!idoc) { return el; }
                        var inner = idoc.activeElement;
                        if (inner && inner !== idoc.body) { root = idoc; el = inner; continue; }
                        return idoc.activeElement || idoc.body;
                    } catch (error) { return el; }
                } else if (el.shadowRoot && el.shadowRoot.activeElement) {
                    el = el.shadowRoot.activeElement; continue;
                }
                break;
            }
            return el;
        }
        try {
            var el = deepActive(document);
            if (!el) { return false; }
            var tag = el.tagName;
            if (tag === 'INPUT' || tag === 'TEXTAREA') {
                var win = (el.ownerDocument && el.ownerDocument.defaultView) || window;
                var proto = (tag === 'TEXTAREA') ?
                    win.HTMLTextAreaElement.prototype : win.HTMLInputElement.prototype;
                var desc = Object.getOwnPropertyDescriptor(proto, 'value');
                var nativeSet = desc && desc.set;
                var next, caret = null;
                if (typeof el.selectionStart === 'number') {
                    var start = el.selectionStart;
                    var end = el.selectionEnd;
                    var current = el.value;
                    next = current.slice(0, start) + text + current.slice(end);
                    caret = start + text.length;
                } else {
                    next = text;
                }
                if (nativeSet) { nativeSet.call(el, next); } else { el.value = next; }
                if (caret !== null) {
                    try { el.setSelectionRange(caret, caret); } catch (error) {}
                }
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            var doc = el.ownerDocument || document;
            if (el.isContentEditable) {
                try { el.focus(); } catch (error) {}
                try { if (doc.execCommand('insertText', false, text)) { return true; } }
                catch (errorE) {}
                try {
                    var sel = doc.getSelection && doc.getSelection();
                    if (sel && sel.rangeCount) {
                        var range = sel.getRangeAt(0);
                        range.deleteContents();
                        var node = doc.createTextNode(text);
                        range.insertNode(node);
                        range.setStartAfter(node);
                        range.setEndAfter(node);
                        sel.removeAllRanges();
                        sel.addRange(range);
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                        return true;
                    }
                } catch (error) {}
                return false;
            }
            try { if (doc.execCommand('insertText', false, text)) { return true; } }
            catch (error) {}
        } catch (error) {}
        return false;
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
