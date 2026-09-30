import Foundation

#if targetEnvironment(macCatalyst)
import CoreAudio

class HACoreAudioObjectSystem: HACoreAudioObject {
    init() {
        super.init(id: UInt32(kAudioObjectSystemObject))
    }

    var allDevices: [HACoreAudioObjectDevice] {
        if let ids = value(for: .allDevices) {
            return ids.map { HACoreAudioObjectDevice(id: $0) }
        } else {
            return []
        }
    }

    var allInputDevices: [HACoreAudioObjectDevice] {
        allDevices.filter(\.isInput)
    }

    var allOutputDevices: [HACoreAudioObjectDevice] {
        allDevices.filter(\.isOutput)
    }

    /// `nil` when CoreAudio has no per-process state to offer, which is the case on macOS 13 and earlier.
    /// Callers fall back to the devices' own stream configuration for direction when that happens.
    var runningDevices: HACoreAudioRunningDevices? {
        guard let ids = value(for: .processObjectList) else { return nil }
        return HACoreAudioRunningDevices(processes: ids.map { HACoreAudioObjectProcess(id: $0) })
    }
}

#endif
