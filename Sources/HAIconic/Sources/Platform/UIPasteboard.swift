#if os(macOS)
import AppKit

/// The general pasteboard, under the name and shape the shared screens already use to copy text.
public final class UIPasteboard {
    public static let general = UIPasteboard()

    private init() {}

    public var string: String? {
        get {
            NSPasteboard.general.string(forType: .string)
        }
        set {
            NSPasteboard.general.clearContents()
            if let newValue {
                NSPasteboard.general.setString(newValue, forType: .string)
            }
        }
    }
}
#endif
