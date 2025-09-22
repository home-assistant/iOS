//
//  DynamicNotificationScene.swift
//  WatchApp
//
//  Created by Bruno Pantaleão on 22/9/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Foundation
import WatchKit
import SwiftUI

final class DynamicNotificationScene: WKUserNotificationHostingController<DynamicNotificationView> {
    private let viewModel = DynamicNotificationViewModel()

    override var body: DynamicNotificationView {
        DynamicNotificationView(viewModel: viewModel)
    }

    override func didReceive(_ notification: UNNotification) {
        viewModel.handle(notification: notification)
    }
}
