#if targetEnvironment(macCatalyst) || os(macOS)
import CoreAudio

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

    /// The connection the device is reached over, named the way the iOS audio route names its ports.
    var transportTypeName: String? {
        guard let transportType = value(for: .transportType) else { return nil }
        switch transportType {
        case UInt32(kAudioDeviceTransportTypeBuiltIn): return "Built-in Speaker"
        case UInt32(kAudioDeviceTransportTypeBluetooth): return "Bluetooth A2DP"
        case UInt32(kAudioDeviceTransportTypeBluetoothLE): return "Bluetooth LE"
        case UInt32(kAudioDeviceTransportTypeUSB): return "Usb Audio"
        case UInt32(kAudioDeviceTransportTypeHDMI): return "HDMI"
        case UInt32(kAudioDeviceTransportTypeDisplayPort): return "DisplayPort"
        case UInt32(kAudioDeviceTransportTypeAirPlay): return "AirPlay"
        case UInt32(kAudioDeviceTransportTypeThunderbolt): return "Thunderbolt"
        case UInt32(kAudioDeviceTransportTypePCI): return "PCI"
        case UInt32(kAudioDeviceTransportTypeFireWire): return "FireWire"
        case UInt32(kAudioDeviceTransportTypeAggregate): return "Aggregate"
        case UInt32(kAudioDeviceTransportTypeVirtual): return "Virtual"
        default: return "Unknown"
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
    /// microphone as in use. `runningDevices` resolves the direction where CoreAudio can tell us, and is
    /// `nil` where it can't.
    func isInputOn(runningDevices: HACoreAudioRunningDevices?) -> Bool {
        guard isInput else { return false }
        guard let runningDevices else { return isOn }
        return runningDevices.isRecording(deviceID: id, isRunningSomewhere: isOn)
    }

    /// Whether the device is currently playing back. See `isInputOn(runningDevices:)`.
    func isOutputOn(runningDevices: HACoreAudioRunningDevices?) -> Bool {
        guard isOutput else { return false }
        guard let runningDevices else { return isOn }
        return runningDevices.isPlayingBack(deviceID: id, isRunningSomewhere: isOn)
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
