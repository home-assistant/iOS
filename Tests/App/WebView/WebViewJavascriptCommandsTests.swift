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

    @Test func testWebViewJavascriptCommandsQuickSearch() async throws {
        assert(WebViewJavascriptCommands.quickSearchKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'k',
            code: 'KeyK',
            keyCode: 75,
            which: 75,
            ctrlKey: true,
            bubbles: true,
            cancelable: true
        });
        document.dispatchEvent(event);
        """)
    }

    @Test func testWebViewJavascriptCommandsSearchDevices() async throws {
        assert(WebViewJavascriptCommands.searchDevicesKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'd',
            code: 'KeyD',
            keyCode: 68,
            which: 68,
            bubbles: true,
            cancelable: true
        });
        document.dispatchEvent(event);
        """)
    }

    @Test func testWebViewJavascriptCommandsSearchCommands() async throws {
        assert(WebViewJavascriptCommands.searchCommandsKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'c',
            code: 'KeyC',
            keyCode: 67,
            which: 67,
            bubbles: true,
            cancelable: true
        });
        document.dispatchEvent(event);
        """)
    }

    @Test func testWebViewJavascriptCommandsAssist() async throws {
        assert(WebViewJavascriptCommands.assistKeyEvent == """
        var event = new KeyboardEvent('keydown', {
            key: 'a',
            code: 'KeyA',
            keyCode: 65,
            which: 65,
            bubbles: true,
            cancelable: true
        });
        document.dispatchEvent(event);
        """)
    }
}
