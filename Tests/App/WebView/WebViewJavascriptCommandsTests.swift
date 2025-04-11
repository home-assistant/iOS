//
//  WebViewJavascriptCommandsTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 11/4/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//
@testable import HomeAssistant
import Testing

struct WebViewJavascriptCommandsTests {
    @Test func testWebViewJavascriptCommandsSearchEntities() async throws {
        assert(WebViewJavascriptCommands.searchEntitiesKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'e',
            code: 'KeyE',
            keyCode: 69,
            which: 69,
            bubbles: true,
            cancelable: true
        });
        document.dispatchEvent(event);
        """)
    }
}
