import Foundation

#if targetEnvironment(macCatalyst)
import CoreAudio

/// Which audio devices are recording and which are playing back, right now, across the whole system.
///
/// This exists because `kAudioDevicePropertyDeviceIsRunningSomewhere` cannot answer that question: it is a
/// device-global flag, with no per-direction meaning, published only in `kAudioObjectPropertyScopeGlobal`.
/// A device that both records and plays back — a USB headset, say — reports itself as running when either
/// direction is in use, which is why playing music through a headset used to turn `Audio Input In Use` on.
/// Direction has to come from the processes doing the IO instead.
struct HACoreAudioRunningDevices {
    let inputDeviceIDs: Set<AudioDeviceID>
    let outputDeviceIDs: Set<AudioDeviceID>
}

extension HACoreAudioRunningDevices {
    init(processes: [HACoreAudioObjectProcess]) {
        var recording = Set<AudioDeviceID>()
        var playingBack = Set<AudioDeviceID>()

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
