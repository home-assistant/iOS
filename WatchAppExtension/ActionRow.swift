//
//  ActionRow.swift
//  WatchAppExtension
//
//  Created by Robert Trencheny on 10/7/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import WatchKit
import Shared
import EMTLoadingIndicator

class ActionRowType: NSObject {
    @IBOutlet weak var group: WKInterfaceGroup!
    @IBOutlet weak var label: WKInterfaceLabel!
    @IBOutlet weak var image: WKInterfaceImage!

    var indicator: EMTLoadingIndicator?
    var icon: MaterialDesignIcons = MaterialDesignIcons.fileQuestionIcon
}
