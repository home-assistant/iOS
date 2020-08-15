//
//  WidgetActionsEntry.swift
//  WidgetsExtension
//
//  Created by Zac West on 8/14/20.
//  Copyright © 2020 Home Assistant. All rights reserved.
//

import Foundation
import Shared
import WidgetKit

struct WidgetActionsEntry: TimelineEntry {
    var date: Date = Date()
    var actions: [Action] = []
}
