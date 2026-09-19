import CoreGraphics
import Foundation

/// Where on screen the frontend was asked for a modal, so it can grow out of what the user touched.
///
/// The rectangle is in CSS pixels of the sending page's viewport, which is the web view's own
/// coordinate space at the default page zoom. The frontend leaves it out when nothing was touched,
/// as a deep link does, and the modal then appears the plain way.
struct NativeModalOrigin: Equatable {
    let rect: CGRect

    init?(payload: Any?) {
        guard let payload = payload as? [String: Any],
              let x = payload["x"] as? Double,
              let y = payload["y"] as? Double,
              let width = payload["width"] as? Double,
              let height = payload["height"] as? Double,
              width > 0, height > 0 else { return nil }
        self.rect = CGRect(x: x, y: y, width: width, height: height)
    }

    init(rect: CGRect) {
        self.rect = rect
    }
}
