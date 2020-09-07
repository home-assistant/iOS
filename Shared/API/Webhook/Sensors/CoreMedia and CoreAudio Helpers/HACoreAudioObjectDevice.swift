#if targetEnvironment(macCatalyst)

class HACoreAudioObjectDevice: HACoreAudioObject {
    var deviceUID: String? {
        if let string = value(for: .deviceUID) {
            return string.takeRetainedValue() as String
        } else {
            // unsure if UID can come back as nil, but it does for CoreMedia
            return nil
        }
    }

    var name: String? {
        if let cfString = value(for: .name) {
            return cfString.takeRetainedValue() as String
        } else {
            return nil
        }
    }

    var manufacturer: String? {
        if let cfString = value(for: .manufacturer) {
            return cfString.takeRetainedValue() as String
        } else {
            return nil
        }
    }

    var isOn: Bool {
        if let isOn = value(for: .isRunningSomewhere) {
            return isOn != 0
        } else {
            return false
        }
    }

    var isInput: Bool {
        if let inputStreams = value(for: .inputStreams) {
            return inputStreams.isEmpty == false
        } else {
            return false
        }
    }

    var isOutput: Bool {
        if let outputStreams = value(for: .outputStreams) {
            return outputStreams.isEmpty == false
        } else {
            return false
        }
    }
}

#endif
