import Foundation

enum WebViewJavascriptCommands {
    static var searchEntitiesKeyEvent = """
    var event = new KeyboardEvent('keydown', {
        key: 'e',
        code: 'KeyE',
        keyCode: 69,
        which: 69,
        bubbles: true,
        cancelable: true
    });
    document.dispatchEvent(event);
    """
}
