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

    /// Whether the device is currently recording.
    ///
    /// `isOn` covers the device as a whole, in either direction, so it can't answer this on its own for a
    /// device that both records and plays back: playing music through a USB headset would report its
    /// microphone as in use. `runningDevices` resolves the direction where CoreAudio can tell us, and the
    /// device's stream configuration is the fallback where it can't.
    func isInputOn(runningDevices: HACoreAudioRunningDevices?) -> Bool {
        guard isInput else { return false }

        if let runningDevices {
            if runningDevices.inputDeviceIDs.contains(id) {
                return true
            }
            if runningDevices.outputDeviceIDs.contains(id) {
                // something is playing back through it, and nothing is recording from it
                return false
            }
        }

        // either there is no per-process state to go on, or nothing claims the device in either direction
        // while it is running - trust the streams it has, as the app did before per-direction attribution
        return isOn
    }

    /// Whether the device is currently playing back. See `isInputOn(runningDevices:)`.
    func isOutputOn(runningDevices: HACoreAudioRunningDevices?) -> Bool {
        guard isOutput else { return false }

        if let runningDevices {
            if runningDevices.outputDeviceIDs.contains(id) {
                return true
            }
            if runningDevices.inputDeviceIDs.contains(id) {
                return false
            }
        }

        return isOn
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
