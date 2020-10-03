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
}

#endif
