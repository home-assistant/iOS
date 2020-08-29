import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObjectCamera: HACoreMediaObject {
    var deviceUID: String {
        if let string = property(for: .deviceUID) {
            return string.takeRetainedValue() as String
        } else {
            return "\(id)"
        }
    }

    var name: String? {
        if let cfString = property(for: .name) {
            return cfString.takeRetainedValue() as String
        } else {
            return nil
        }
    }

    var manufacturer: String? {
        if let cfString = property(for: .manufacturer) {
            return cfString.takeRetainedValue() as String
        } else {
            return nil
        }
    }

    var isOn: Bool {
        if let isOn = property(for: .isRunningSomewhere) {
            return isOn != 0
        } else {
            return false
        }
    }
}

#endif
