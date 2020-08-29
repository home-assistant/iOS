import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObjectSystem: HACoreMediaObject {
    init() {
        super.init(id: CMIOObjectID(kCMIOObjectSystemObject))
    }

    var allCameras: [HACoreMediaObjectCamera] {
        if let ids = value(for: .allDevices) {
            return ids.map { HACoreMediaObjectCamera(id: $0) }
        } else {
            return []
        }
    }
}

#endif
