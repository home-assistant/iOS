import UIKit
@preconcurrency import WebKit

/// On macOS 27, WebKit presents `<input type="time">` with a wheel-style picker. `UIPickerView` is
/// unsupported under the Mac idiom and throws as soon as it joins a window, which crashes the app (for
/// example from the charging plan in evcc's web UI).
///
/// The script keeps WebKit from ever presenting that picker: it makes time inputs read-only, which stops
/// WebKit from starting an input session when one gains focus via the keyboard, and it intercepts clicks,
/// label clicks and keyboard activation. Instead it asks `CatalystTimeInputMessageHandler` to lay a native
/// `UIDatePicker` over the input.
enum CatalystTimeInputWorkaround {
    static let messageName = "timeInput"

    static var isNeeded: Bool {
        UIDevice.current.userInterfaceIdiom == .mac
    }

    /// Installed in every frame so iframe panels and ingress add-ons are covered too.
    static var userScript: WKUserScript {
        WKUserScript(
            source: """
            (function() {
                "use strict";
                if (window.__haTimeInput) { return; }
                const handler = window.webkit && window.webkit.messageHandlers
                    && window.webkit.messageHandlers.\(messageName);
                if (!handler) { return; }

                // WebKit opens no picker when a read-only time input gains focus (e.g. via Tab), so every time input
                // is made read-only; this marker tells ours apart from inputs the page made read-only itself.
                const marker = "data-ha-time-input";
                const pending = new Map();
                // Token of the input the native overlay currently covers, if this frame is on its path.
                let activeToken = null;

                function isTimeInput(element) {
                    return element instanceof HTMLInputElement && element.type === "time";
                }

                function isEditable(input) {
                    return !input.disabled && (!input.readOnly || input.hasAttribute(marker));
                }

                function protect(input) {
                    if (!input.hasAttribute("readonly")) {
                        input.setAttribute(marker, "");
                        input.setAttribute("readonly", "");
                    }
                }

                function protectAll(node) {
                    if (isTimeInput(node)) {
                        protect(node);
                    } else if (node.querySelectorAll) {
                        node.querySelectorAll("input[type=time]").forEach(protect);
                    }
                }

                new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                        if (mutation.type === "attributes") {
                            protectAll(mutation.target);
                        } else {
                            mutation.addedNodes.forEach(protectAll);
                        }
                    });
                }).observe(document, {
                    subtree: true,
                    childList: true,
                    attributes: true,
                    attributeFilter: ["type", "readonly"],
                });
                protectAll(document);

                function rectOf(element) {
                    const rect = element.getBoundingClientRect();
                    return { x: rect.left, y: rect.top, width: rect.width, height: rect.height };
                }

                // The native side needs the field's position in the main frame. Frames can be cross-origin, so each
                // frame adds its own offset and hands the rect up to its parent until it reaches the top.
                function findFrame(root, source) {
                    const elements = root.querySelectorAll("*");
                    for (let index = 0; index < elements.length; index++) {
                        const element = elements[index];
                        if ((element instanceof HTMLIFrameElement || element instanceof HTMLFrameElement)
                            && element.contentWindow === source) {
                            return element;
                        }
                        if (element.shadowRoot) {
                            const frame = findFrame(element.shadowRoot, source);
                            if (frame) { return frame; }
                        }
                    }
                    return null;
                }

                function sendAnchor(token, rect) {
                    activeToken = token;
                    if (window.top === window) {
                        handler.postMessage({
                            kind: "anchor",
                            token: token,
                            rect: rect,
                            viewportWidth: window.innerWidth,
                        });
                    } else {
                        window.parent.postMessage({ haTimeInputAnchor: { token: token, rect: rect } }, "*");
                    }
                }

                window.addEventListener("message", function(event) {
                    const anchor = event.data && event.data.haTimeInputAnchor;
                    if (!anchor || typeof anchor.token !== "string" || !anchor.rect) { return; }
                    const frame = findFrame(document, event.source);
                    if (!frame) { return; }
                    const frameRect = frame.getBoundingClientRect();
                    sendAnchor(anchor.token, {
                        x: Number(anchor.rect.x) + frameRect.left + frame.clientLeft,
                        y: Number(anchor.rect.y) + frameRect.top + frame.clientTop,
                        width: Number(anchor.rect.width),
                        height: Number(anchor.rect.height),
                    });
                });

                function dismiss() {
                    if (activeToken === null) { return; }
                    handler.postMessage({ kind: "dismiss", token: activeToken });
                    activeToken = null;
                }

                document.addEventListener("scroll", dismiss, true);
                window.addEventListener("resize", dismiss);

                // clickX: where in the input the user clicked, as a fraction of its width, if it was a click.
                function open(input, clickX) {
                    const token = Math.random().toString(36).slice(2);
                    pending.clear();
                    pending.set(token, input);
                    const style = getComputedStyle(input);
                    // WebKit draws the value in this pseudo-element, which can be aligned independently of the input.
                    const valueStyle = getComputedStyle(input, "::-webkit-date-and-time-value");
                    handler.postMessage({
                        kind: "open",
                        token: token,
                        value: input.value,
                        step: Number(input.getAttribute("step")) || 60,
                        borderRadius: parseFloat(style.borderTopLeftRadius) || 0,
                        textAlign: valueStyle.textAlign || style.textAlign,
                        direction: style.direction,
                        paddingLeft: (parseFloat(style.paddingLeft) || 0) + (parseFloat(style.borderLeftWidth) || 0),
                        paddingRight: (parseFloat(style.paddingRight) || 0) + (parseFloat(style.borderRightWidth) || 0),
                        clickX: clickX,
                    });
                    sendAnchor(token, rectOf(input));
                }

                Object.defineProperty(window, "__haTimeInput", {
                    value: Object.freeze({
                        set: function(token, value) {
                            const input = pending.get(token);
                            if (!input || !input.isConnected) { return; }
                            input.value = value;
                            input.dispatchEvent(new Event("input", { bubbles: true, composed: true }));
                            input.dispatchEvent(new Event("change", { bubbles: true }));
                        },
                    }),
                });

                document.addEventListener("mousedown", function(event) {
                    if (event.button !== 0) { return; }
                    const input = event.composedPath().find(isTimeInput);
                    if (!input) {
                        dismiss();
                        return;
                    }
                    // Even a read-only time input crashes when clicked, so never let WebKit handle the click.
                    event.preventDefault();
                    event.stopImmediatePropagation();
                    if (isEditable(input)) {
                        const rect = input.getBoundingClientRect();
                        open(input, rect.width > 0 ? (event.clientX - rect.left) / rect.width : null);
                    }
                }, true);

                // A label click focuses its control; open the picker instead.
                document.addEventListener("click", function(event) {
                    const label = event.composedPath().find(function(element) {
                        return element instanceof HTMLLabelElement;
                    });
                    if (label && isTimeInput(label.control)) {
                        event.preventDefault();
                        if (isEditable(label.control)) { open(label.control, null); }
                    }
                }, true);

                // Keyboard access for a focused time input, which no longer accepts typing.
                document.addEventListener("keydown", function(event) {
                    if (event.key === "Tab" || event.key === "Escape") { dismiss(); }
                    const input = event.composedPath().find(isTimeInput);
                    if (!input || !isEditable(input)) { return; }
                    const opensPicker = event.code === "Space" || event.key === "Enter"
                        || event.key === "ArrowDown" || event.key === "ArrowUp";
                    if (opensPicker) {
                        event.preventDefault();
                        open(input, null);
                    }
                }, true);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}
