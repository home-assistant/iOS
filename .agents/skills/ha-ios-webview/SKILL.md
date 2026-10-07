---
name: ha-ios-webview
description: The WKWebView frontend that renders the Home Assistant web UI. Use when working on WebViewController and its WebViewController+*.swift extensions, the JavaScript external message bus, custom URL schemes, or deep links into the frontend.
---

# The WKWebView Frontend

The primary iOS UI is a `WKWebView` (`WebViewController`) that renders the Home Assistant web frontend; native Swift code wraps it with platform integrations. `WebViewController` functionality is spread across many `WebViewController+*.swift` extension files (navigation, gestures, alerts, URL loading, etc.). Native features communicate with the web UI via a JavaScript message bus handled by `WebViewExternalMessageHandler` (messages typed as `WebViewExternalBusMessage` / `WebViewExternalBusOutgoingMessage` in `Sources/App/Frontend/ExternalMessageBus/`) and custom URL schemes / deep links defined in `AppConstants`.
