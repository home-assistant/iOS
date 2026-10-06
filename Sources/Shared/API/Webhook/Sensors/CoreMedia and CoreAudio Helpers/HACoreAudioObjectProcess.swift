import Foundation

#if targetEnvironment(macCatalyst)
import CoreAudio

/// One of the processes doing audio IO on the system, from `kAudioHardwarePropertyProcessObjectList`.
///
/// These objects are the only place CoreAudio reports the *direction* of activity:
/// `kAudioDevicePropertyDeviceIsRunningSomewhere` is device-global and says nothing about whether the
/// device is recording, playing back, or both.
class HACoreAudioObjectProcess: HACoreAudioObject {
    var isRunningInput: Bool {
        if let isRunning = value(for: .isProcessRunningInput) {
            return isRunning != 0
        } else {
            return false
        }
    }

    var isRunningOutput: Bool {
        if let isRunning = value(for: .isProcessRunningOutput) {
            return isRunning != 0
        } else {
            return false
        }
    }

    var inputDeviceIDs: [AudioDeviceID] {
        value(for: .processInputDevices) ?? []
    }

    var outputDeviceIDs: [AudioDeviceID] {
        value(for: .processOutputDevices) ?? []
    }
}

#endif
