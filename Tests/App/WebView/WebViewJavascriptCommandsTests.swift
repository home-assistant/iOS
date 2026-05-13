//
//  WebViewJavascriptCommandsTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 11/4/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//
@testable import HomeAssistant
import Testing
import UIKit

struct WebViewJavascriptCommandsTests {
    @Test func testSetAppSafeAreaInsetsCommand() async throws {
        assert(WebViewJavascriptCommands.setAppSafeAreaInsets(.init(
            top: 47,
            left: 3.5,
            bottom: 21,
            right: 0
        )) == """
        document.documentElement.style.setProperty('--app-safe-area-inset-top', '47.00px');
        document.documentElement.style.setProperty('--app-safe-area-inset-bottom', '21.00px');
        document.documentElement.style.setProperty('--app-safe-area-inset-left', '3.50px');
        document.documentElement.style.setProperty('--app-safe-area-inset-right', '0.00px');
        """)
    }

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
            metaKey: true,
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
