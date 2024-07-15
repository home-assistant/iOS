//
//  WebViewExternalMessageHandler+Build.swift
//  App
//
//  Created by Bruno Pantaleão on 15/07/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Improv_iOS

extension WebViewExternalMessageHandler {
    static func build() -> WebViewExternalMessageHandler {
        WebViewExternalMessageHandler(improvManager: ImprovManager.shared)
    }
}
