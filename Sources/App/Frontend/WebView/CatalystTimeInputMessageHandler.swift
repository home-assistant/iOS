import UIKit
@preconcurrency import WebKit

/// Lays a `CatalystTimeInputOverlayView` over the time inputs that `CatalystTimeInputWorkaround.userScript`
/// intercepts, and writes the picked value back into the frame the input lives in.
///
/// A field reports itself with an `open` message from its own frame; its position in the main frame
/// arrives separately as an `anchor` message from the main frame, since cross-origin frames cannot
/// measure their own offset. Any frame on that path sends `dismiss` once the page scrolls, resizes or is
/// clicked elsewhere, because the overlay would no longer line up with the input.
final class CatalystTimeInputMessageHandler: NSObject, WKScriptMessageHandler {
    private struct Request {
        let token: String
        let frame: WKFrameInfo
        let value: String
        let step: Int
        /// How round the input's corners are, in CSS pixels.
        let borderRadius: Double
        let textAlign: String
        let direction: String
        /// Padding plus border on each side, in CSS pixels.
        let paddingLeft: Double
        let paddingRight: Double
        /// Where in the input the user clicked, as a fraction of its width; `nil` for keyboard activation.
        let clickX: Double?
    }

    private struct Anchor {
        let token: String
        let rect: CGRect
        let scale: CGFloat
    }

    private let webViewProvider: () -> WKWebView?
    private var pendingRequest: Request?
    private var pendingAnchor: Anchor?
    private weak var overlay: CatalystTimeInputOverlayView?

    init(webViewProvider: @escaping () -> WKWebView?) {
        self.webViewProvider = webViewProvider
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let token = body["token"] as? String else { return }

        switch body["kind"] as? String {
        case "open":
            removeOverlay()
            let request = Request(
                token: token,
                frame: message.frameInfo,
                value: body["value"] as? String ?? "",
                step: (body["step"] as? NSNumber)?.intValue ?? 60,
                borderRadius: (body["borderRadius"] as? NSNumber)?.doubleValue ?? 0,
                textAlign: body["textAlign"] as? String ?? "",
                direction: body["direction"] as? String ?? "ltr",
                paddingLeft: (body["paddingLeft"] as? NSNumber)?.doubleValue ?? 0,
                paddingRight: (body["paddingRight"] as? NSNumber)?.doubleValue ?? 0,
                clickX: (body["clickX"] as? NSNumber)?.doubleValue
            )
            if let anchor = pendingAnchor, anchor.token == token {
                show(request, at: anchor)
            } else {
                pendingRequest = request
            }
        case "anchor":
            guard message.frameInfo.isMainFrame, let webView = webViewProvider(),
                  let cssRect = Self.rect(from: body) else { return }
            let scale = Self.scale(viewportWidth: (body["viewportWidth"] as? NSNumber)?.doubleValue, in: webView)
            let anchor = Anchor(
                token: token,
                rect: Self.webViewRect(for: cssRect, scale: scale, in: webView),
                scale: scale
            )
            if let request = pendingRequest, request.token == token {
                show(request, at: anchor)
            } else {
                // The anchor can overtake the open message when the two come from different frames.
                pendingAnchor = anchor
            }
        case "dismiss":
            if overlay?.token == token {
                removeOverlay()
            }
        default:
            break
        }
    }

    static func rect(from body: [String: Any]) -> CGRect? {
        guard let rect = body["rect"] as? [String: Any],
              let x = (rect["x"] as? NSNumber)?.doubleValue,
              let y = (rect["y"] as? NSNumber)?.doubleValue,
              let width = (rect["width"] as? NSNumber)?.doubleValue,
              let height = (rect["height"] as? NSNumber)?.doubleValue else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Maps the CSS `text-align` of the input's value to where the overlay puts the time.
    static func alignment(
        textAlign: String,
        direction: String,
        paddingLeft: CGFloat,
        paddingRight: CGFloat
    ) -> CatalystTimeInputOverlayView.Alignment {
        let isRightToLeft = direction == "rtl"
        switch textAlign {
        case "center", "-webkit-center":
            return .center
        case "right", "-webkit-right":
            return .right(inset: paddingRight)
        case "end":
            return isRightToLeft ? .left(inset: paddingLeft) : .right(inset: paddingRight)
        case "left", "-webkit-left":
            return .left(inset: paddingLeft)
        default:
            return isRightToLeft ? .right(inset: paddingRight) : .left(inset: paddingLeft)
        }
    }

    /// Web view points per CSS pixel; the page may be zoomed.
    static func scale(viewportWidth: Double?, in webView: WKWebView) -> CGFloat {
        guard let viewportWidth, viewportWidth > 0 else { return 1 }
        return webView.bounds.width / CGFloat(viewportWidth)
    }

    /// Converts a CSS-pixel rect from the main frame into web view points.
    static func webViewRect(for cssRect: CGRect, scale: CGFloat, in webView: WKWebView) -> CGRect {
        // Client coordinates are relative to the visible viewport, which starts at the content inset.
        let inset = webView.scrollView.adjustedContentInset
        return CGRect(
            x: cssRect.minX * scale + inset.left,
            y: cssRect.minY * scale + inset.top,
            width: cssRect.width * scale,
            height: cssRect.height * scale
        )
    }

    private func show(_ request: Request, at anchor: Anchor) {
        pendingRequest = nil
        pendingAnchor = nil
        guard let webView = webViewProvider() else { return }

        let overlay = CatalystTimeInputOverlayView(token: request.token, value: request.value, step: request.step) {
            [weak webView] value in
            webView?.callAsyncJavaScript(
                "window.__haTimeInput && window.__haTimeInput.set(token, value)",
                arguments: ["token": request.token, "value": value],
                in: request.frame,
                in: .page
            )
        }
        webView.addSubview(overlay)
        overlay.place(
            over: anchor.rect,
            cornerRadius: CGFloat(request.borderRadius) * anchor.scale,
            alignment: Self.alignment(
                textAlign: request.textAlign,
                direction: request.direction,
                paddingLeft: CGFloat(request.paddingLeft) * anchor.scale,
                paddingRight: CGFloat(request.paddingRight) * anchor.scale
            )
        )
        let clickPoint = request.clickX.map {
            CGPoint(x: anchor.rect.minX + CGFloat($0) * anchor.rect.width, y: anchor.rect.midY)
        }
        overlay.beginEditing(near: clickPoint.map { webView.convert($0, to: overlay) })
        self.overlay = overlay
    }

    private func removeOverlay() {
        overlay?.removeFromSuperview()
        overlay = nil
    }
}
