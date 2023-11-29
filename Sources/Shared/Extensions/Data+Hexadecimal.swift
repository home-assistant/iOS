//
//  Data+Hexadecimal.swift
//  App
//
//  Created by Bruno Pantaleão on 29/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation

public extension Data {
    var hexadecimal: String {
        map { String(format: "%02x", $0) }
            .joined()
    }
}
