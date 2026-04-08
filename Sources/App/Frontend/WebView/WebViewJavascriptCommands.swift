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

    static var scrollFocusedElementIntoView = """
    (function() {
        function activeElement(root) {
            let element = root.activeElement;

            while (element && element.shadowRoot && element.shadowRoot.activeElement) {
                element = element.shadowRoot.activeElement;
            }

            return element;
        }

        const element = activeElement(document);
        if (!element) {
            return false;
        }

        const tagName = element.tagName ? element.tagName.toUpperCase() : '';
        const isEditable = element.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(tagName);
        if (!isEditable) {
            return false;
        }

        const viewport = window.visualViewport;
        const viewportHeight = viewport ? viewport.height : window.innerHeight;
        const viewportOffsetTop = viewport ? viewport.offsetTop : 0;
        const padding = 24;
        const rect = element.getBoundingClientRect();
        const visibleTop = viewportOffsetTop + padding;
        const visibleBottom = viewportOffsetTop + viewportHeight - padding;

        if (rect.top >= visibleTop && rect.bottom <= visibleBottom) {
            return true;
        }

        element.scrollIntoView({
            block: 'center',
            inline: 'nearest',
            behavior: 'auto'
        });
        return true;
    })();
    """
}
