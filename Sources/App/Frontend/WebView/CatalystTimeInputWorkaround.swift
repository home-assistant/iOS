import UIKit
@preconcurrency import WebKit

/// On macOS 27, WebKit presents `<input type="time">` with a wheel-style picker. `UIPickerView` is
/// unsupported under the Mac idiom and throws as soon as it joins a window, which crashes the app (for
/// example from the charging plan in evcc's web UI). This script intercepts the click before WebKit can
/// focus the field and offers hour and minute `<select>`s instead, which WebKit shows as native menus.
enum CatalystTimeInputWorkaround {
    static var isNeeded: Bool {
        UIDevice.current.userInterfaceIdiom == .mac
    }

    /// Installed in every frame so iframe panels and ingress add-ons are covered too.
    static var userScript: WKUserScript {
        WKUserScript(
            source: """
            (function() {
                "use strict";
                if (window.__haTimePickerInstalled) { return; }
                window.__haTimePickerInstalled = true;

                let open = null;

                function isTimeInput(element) {
                    return element instanceof HTMLInputElement && element.type === "time"
                        && !element.disabled && !element.readOnly;
                }

                function pad(number) {
                    return String(number).padStart(2, "0");
                }

                function close() {
                    if (!open) { return; }
                    open.host.remove();
                    open = null;
                    window.removeEventListener("resize", close, true);
                    document.removeEventListener("keydown", onKeyDown, true);
                }

                function onKeyDown(event) {
                    if (event.key === "Escape") {
                        event.preventDefault();
                        const input = open.input;
                        close();
                        input.focus({ preventScroll: true });
                    }
                }

                function show(input) {
                    close();
                    const step = Number(input.getAttribute("step")) || 60;
                    const minuteStep = step >= 60 && step % 60 === 0 && 60 % (step / 60) === 0 ? step / 60 : 1;
                    const parts = (input.value || "").split(":");
                    const hour = parts.length >= 2 ? Number(parts[0]) : new Date().getHours();
                    const minute = parts.length >= 2 ? Number(parts[1]) : 0;
                    const seconds = parts.length >= 3 ? ":" + parts.slice(2).join(":") : "";

                    const host = document.createElement("div");
                    host.style.cssText = "position:fixed;inset:0;z-index:2147483647;";
                    const root = host.attachShadow({ mode: "open" });
                    root.innerHTML = "<style>" +
                        ".panel{position:fixed;display:flex;align-items:center;gap:4px;padding:8px;" +
                        "font:13px -apple-system,system-ui,sans-serif;color:#000;background:rgba(246,246,246,.98);" +
                        "border:.5px solid rgba(0,0,0,.2);border-radius:8px;box-shadow:0 8px 24px rgba(0,0,0,.25)}" +
                        "select{font:inherit}" +
                        "@media (prefers-color-scheme:dark){.panel{color:#fff;background:rgba(40,40,40,.98);" +
                        "border-color:rgba(255,255,255,.15)}}" +
                        "</style>" +
                        "<div class=panel><select class=hour aria-label=Hour></select>:" +
                        "<select class=minute aria-label=Minute></select></div>";

                    const hourSelect = root.querySelector(".hour");
                    const minuteSelect = root.querySelector(".minute");
                    for (let value = 0; value < 24; value++) {
                        hourSelect.add(new Option(pad(value), value, false, value === hour));
                    }
                    for (let value = 0; value < 60; value += minuteStep) {
                        minuteSelect.add(new Option(pad(value), value));
                    }
                    if (minute % minuteStep !== 0) {
                        minuteSelect.add(new Option(pad(minute), minute));
                    }
                    minuteSelect.value = String(minute);

                    function apply() {
                        input.value = pad(hourSelect.value) + ":" + pad(minuteSelect.value) + seconds;
                        input.dispatchEvent(new Event("input", { bubbles: true, composed: true }));
                        input.dispatchEvent(new Event("change", { bubbles: true }));
                    }
                    hourSelect.addEventListener("change", apply);
                    minuteSelect.addEventListener("change", apply);

                    host.addEventListener("mousedown", function(event) {
                        if (event.composedPath()[0] === host) {
                            event.preventDefault();
                            close();
                        }
                    });

                    (document.body || document.documentElement).appendChild(host);
                    open = { host: host, input: input };

                    const panel = root.querySelector(".panel");
                    const rect = input.getBoundingClientRect();
                    const panelRect = panel.getBoundingClientRect();
                    const fitsBelow = rect.bottom + 4 + panelRect.height <= window.innerHeight;
                    panel.style.top = (fitsBelow ? rect.bottom + 4 : Math.max(4, rect.top - 4 - panelRect.height)) + "px";
                    panel.style.left = Math.max(4, Math.min(rect.left, window.innerWidth - 4 - panelRect.width)) + "px";

                    window.addEventListener("resize", close, true);
                    document.addEventListener("keydown", onKeyDown, true);
                }

                document.addEventListener("mousedown", function(event) {
                    if (event.button !== 0) { return; }
                    const input = event.composedPath().find(isTimeInput);
                    if (!input) { return; }
                    event.preventDefault();
                    if (open && open.input === input) {
                        close();
                    } else {
                        show(input);
                    }
                }, true);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}
