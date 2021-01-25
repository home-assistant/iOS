import AppKit

extension NSEvent {
    var isRightClickEquivalentEvent: Bool {
        switch type {
        case .rightMouseUp, .rightMouseDown: return true
        case .leftMouseUp, .leftMouseDown: return modifierFlags.contains(.control)
        default: return false
        }
    }
}
