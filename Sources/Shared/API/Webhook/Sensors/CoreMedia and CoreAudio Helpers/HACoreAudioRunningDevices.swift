import Foundation

/// Which audio devices are recording and which are playing back, right now, across the whole system.
///
/// This exists because `kAudioDevicePropertyDeviceIsRunningSomewhere` cannot answer that question: it is a
/// device-global flag, with no per-direction meaning, published only in `kAudioObjectPropertyScopeGlobal`.
/// A device that both records and plays back — a USB headset, say — reports itself as running when either
/// direction is in use, which is why playing music through a headset used to turn `Audio Input In Use` on.
/// Direction has to come from the processes doing the IO instead.
struct HACoreAudioRunningDevices {
    let inputDeviceIDs: Set<UInt32>
    let outputDeviceIDs: Set<UInt32>
}

extension HACoreAudioRunningDevices {
    /// Whether the device is recording, given the device-global running flag as a fallback.
    ///
    /// A process doing input IO on the device settles it. So does a process doing only output IO on it:
    /// something is playing through it and nothing is recording from it. A device that is running while no
    /// process claims it in either direction falls back to the global flag, which is what the app relied on
    /// before it looked at direction at all.
    func isRecording(deviceID: UInt32, isRunningSomewhere: Bool) -> Bool {
        if inputDeviceIDs.contains(deviceID) {
            return true
        }
        if outputDeviceIDs.contains(deviceID) {
            return false
        }
        return isRunningSomewhere
    }

    /// Whether the device is playing back. See `isRecording(deviceID:isRunningSomewhere:)`.
    func isPlayingBack(deviceID: UInt32, isRunningSomewhere: Bool) -> Bool {
        if outputDeviceIDs.contains(deviceID) {
            return true
        }
        if inputDeviceIDs.contains(deviceID) {
            return false
        }
        return isRunningSomewhere
    }
}

#if targetEnvironment(macCatalyst)
extension HACoreAudioRunningDevices {
    init(processes: [HACoreAudioObjectProcess]) {
        var recording = Set<UInt32>()
        var playingBack = Set<UInt32>()

        for process in processes {
            if process.isRunningInput {
                recording.formUnion(process.inputDeviceIDs)
            }
            if process.isRunningOutput {
                playingBack.formUnion(process.outputDeviceIDs)
            }
        }

        self.init(inputDeviceIDs: recording, outputDeviceIDs: playingBack)
    }
}
#endif
