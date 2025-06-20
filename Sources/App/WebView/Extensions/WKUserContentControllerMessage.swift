//
//  WKUserContentControllerMessage.swift
//  App
//
//  Created by Bruno Pantaleão on 20/6/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Foundation

enum WKUserContentControllerMessage: String, CaseIterable {
    case externalBus
    case updateThemeColors
    case getExternalAuth
    case revokeExternalAuth
    case logError
}
