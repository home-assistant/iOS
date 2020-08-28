//
//  HACoreMediaObjectCamera.swift
//  HomeAssistant
//
//  Created by Zac West on 8/28/20.
//  Copyright © 2020 Home Assistant. All rights reserved.
//

import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObjectCamera: HACoreMediaObject {
    var deviceID: String {
        if let string: CFString = propertyData(for: .deviceID) {
            return string as String
        } else {
            return "\(id)"
        }
    }

    var name: String? {
        if let cfString: CFString = propertyData(for: .cameraName) {
            return cfString as String
        } else {
            return nil
        }
    }

    var manufacturer: String? {
        if let cfString: CFString = propertyData(for: .cameraManufacturer) {
            return cfString as String
        } else {
            return nil
        }
    }

    var isOn: Bool {
        if let anyOn: [Int32] = propertyArray(for: .cameraIsOn) {
            return anyOn.contains(where: { $0 != 0 })
        } else {
            return false
        }
    }
}

#endif
