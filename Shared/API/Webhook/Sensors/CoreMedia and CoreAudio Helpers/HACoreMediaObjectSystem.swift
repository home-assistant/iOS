import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObjectSystem: HACoreBlahObject {
    init() {
        super.init(id: CMIOObjectID(kCMIOObjectSystemObject))
    }

    var allCameras: [HACoreMediaObjectCamera] {
        if let ids = value(for: .cmAllDevices) {
            return ids.map { HACoreMediaObjectCamera(id: $0) }
        } else {
            return []
        }
    }
}

#endif
