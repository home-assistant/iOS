import Foundation

enum WebViewJavascriptCommands {
    static var searchEntitiesKeyEvent = keyDownEvent(key: "e", code: "KeyE", keyCode: 69)
    static var quickSearchKeyEvent = keyDownEvent(key: "k", code: "KeyK", keyCode: 75, metaKey: true)
    static var searchDevicesKeyEvent = keyDownEvent(key: "d", code: "KeyD", keyCode: 68)
    static var searchCommandsKeyEvent = keyDownEvent(key: "c", code: "KeyC", keyCode: 67)
    static var assistKeyEvent = keyDownEvent(key: "a", code: "KeyA", keyCode: 65)

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
