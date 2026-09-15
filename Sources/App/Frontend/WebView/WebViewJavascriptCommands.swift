import Foundation

enum WebViewJavascriptCommands {
    static var searchEntitiesKeyEvent = keyDownEvent(key: "e", code: "KeyE", keyCode: 69)
    static var quickSearchKeyEvent = keyDownEvent(key: "k", code: "KeyK", keyCode: 75, metaKey: true)
    static var searchDevicesKeyEvent = keyDownEvent(key: "d", code: "KeyD", keyCode: 68)
    static var searchCommandsKeyEvent = keyDownEvent(key: "c", code: "KeyC", keyCode: 67)
    static var assistKeyEvent = keyDownEvent(key: "a", code: "KeyA", keyCode: 65)

    static let frontendRenderedProbe = """
    (function() {
        var frontend = document.querySelector('home-assistant');
        if (frontend && frontend.shadowRoot && frontend.shadowRoot.firstElementChild) {
            return true;
        }
        var body = document.body;
        if (!body) {
            return false;
        }
        if ((body.innerText || '').trim().length > 0) {
            return true;
        }
        return body.querySelector('img, svg, canvas, video, input, button, a, iframe, embed, object') !== null;
    })();
    """

    private static func keyDownEvent(key: String, code: String, keyCode: Int, metaKey: Bool = false) -> String {
        """
        var event = new KeyboardEvent('keydown', {
            key: '\(key)',
            code: '\(code)',
            keyCode: \(keyCode),
            which: \(keyCode),
            metaKey: \(metaKey),
            bubbles: true,
            cancelable: true
        });
        (document.body || document.documentElement || document).dispatchEvent(event);
        """
    }
}
