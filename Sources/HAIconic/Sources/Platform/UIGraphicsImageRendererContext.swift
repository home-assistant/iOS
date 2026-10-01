#if os(macOS)
import AppKit

public final class UIGraphicsImageRendererContext {
    public let cgContext: CGContext

    init(cgContext: CGContext) {
        self.cgContext = cgContext
    }
}
#endif
