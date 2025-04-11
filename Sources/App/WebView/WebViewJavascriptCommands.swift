//
//  WebViewJavascriptCommands.swift
//  App
//
//  Created by Bruno Pantaleão on 11/4/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

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
