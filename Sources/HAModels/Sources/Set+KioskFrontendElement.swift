import Foundation

public extension Set<KioskFrontendElement> {
    /// Adds `element` when `isHidden` is true and removes it otherwise, which is what flipping that
    /// element's switch on the hidden elements screen does.
    mutating func setHidden(_ isHidden: Bool, for element: KioskFrontendElement) {
        if isHidden {
            insert(element)
        } else {
            remove(element)
        }
    }
}
