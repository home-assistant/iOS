import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObjectCamera: HACoreBlahObject {
    var deviceUID: String? {
        if let string = value(for: .cmDeviceUID) {
            return string.takeRetainedValue() as String
        } else {
            // UID can actually come back as nil occasionally
            return nil
        }
    }

    var name: String? {
        if let cfString = value(for: .cmName) {
            return cfString.takeRetainedValue() as String
        } else {
            return nil
        }
    }

    var manufacturer: String? {
        if let cfString = value(for: .cmManufacturer) {
            return cfString.takeRetainedValue() as String
        } else {
            return nil
        }
    }

    var isOn: Bool {
        if let isOn = value(for: .cmIsRunningSomewhere) {
            return isOn != 0
        } else {
            return false
        }
    }
}

#endif
