import Foundation
import UIKit

enum WebViewJavascriptCommands {
    static func setAppSafeAreaInsets(_ insets: UIEdgeInsets) -> String {
        func cssPixels(_ value: CGFloat) -> String {
            String(format: "%.2fpx", locale: Locale(identifier: "en_US_POSIX"), value)
        }

        return """
        document.documentElement.style.setProperty('--app-safe-area-inset-top', '\(cssPixels(insets.top))');
        document.documentElement.style.setProperty('--app-safe-area-inset-bottom', '\(cssPixels(insets.bottom))');
        document.documentElement.style.setProperty('--app-safe-area-inset-left', '\(cssPixels(insets.left))');
        document.documentElement.style.setProperty('--app-safe-area-inset-right', '\(cssPixels(insets.right))');
        """
    }

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

    static var quickSearchKeyEvent = """
    var event = new KeyboardEvent('keydown', {
        key: 'k',
        code: 'KeyK',
        keyCode: 75,
        which: 75,
        metaKey: true,
        bubbles: true,
        cancelable: true
    });
    document.dispatchEvent(event);
    """

    static var searchDevicesKeyEvent = """
    var event = new KeyboardEvent('keydown', {
        key: 'd',
        code: 'KeyD',
        keyCode: 68,
        which: 68,
        bubbles: true,
        cancelable: true
    });
    document.dispatchEvent(event);
    """

    static var searchCommandsKeyEvent = """
    var event = new KeyboardEvent('keydown', {
        key: 'c',
        code: 'KeyC',
        keyCode: 67,
        which: 67,
        bubbles: true,
        cancelable: true
    });
    document.dispatchEvent(event);
    """

    static var assistKeyEvent = """
    var event = new KeyboardEvent('keydown', {
        key: 'a',
        code: 'KeyA',
        keyCode: 65,
        which: 65,
        bubbles: true,
        cancelable: true
    });
    document.dispatchEvent(event);
    """
}
