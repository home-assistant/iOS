import Foundation

#if targetEnvironment(macCatalyst)
import CoreAudio

class HACoreAudioObjectSystem: HACoreBlahObject {
    init() {
        super.init(id: UInt32(kAudioObjectSystemObject))
    }

    var allDevices: [HACoreAudioObjectDevice] {
        if let ids = value(for: .caAllDevices) {
            return ids.map { HACoreAudioObjectDevice(id: $0) }
        } else {
            return []
        }
    }
}

#endif
