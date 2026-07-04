//
//  WidgetPushHandlerModifier.swift
//  HomeAssistant
//
//  Created by Hariharan on 29/06/26.
//  Copyright © 2026 Home Assistant. All rights reserved.
//

import SwiftUI
import WidgetKit

extension WidgetConfiguration {
    func haWidgetPushHandlerIfAvailable() -> some WidgetConfiguration {
        if #available(iOS 26.0, *) {
            return self.pushHandler(HAWidgetPushHandler.self)
        } else {
            return self
        }
    }
}
