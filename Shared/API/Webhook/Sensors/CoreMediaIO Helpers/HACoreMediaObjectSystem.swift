//
//  HACoreMediaObjectSystem.swift
//  HomeAssistant
//
//  Created by Zac West on 8/28/20.
//  Copyright © 2020 Home Assistant. All rights reserved.
//

import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObjectSystem: HACoreMediaObject {
    init() {
        super.init(id: CMIOObjectID(kCMIOObjectSystemObject))
    }

    var allCameras: [HACoreMediaObjectCamera] {
        if let ids: [CMIOObjectID] = propertyArray(for: .allCameras) {
            return ids.map { HACoreMediaObjectCamera(id: $0) }
        } else {
            return []
        }
    }
}

#endif
