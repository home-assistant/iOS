//
//  FrontendStorage.swift
//  App
//
//  Created by Bruno Pantaleão on 21/5/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Foundation

enum FrontendStorage: String {
    case local
    case session
}

enum FrontendStorageOperation {
    case set
    case get
    case remove
    case clear
}
