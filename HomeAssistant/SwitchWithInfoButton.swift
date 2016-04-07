//
//  SwitchWithInfoButton.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/6/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Eureka

import Foundation
public final class SwitchWithInfoButtonCell : Cell<Bool>, CellType {
    
    @IBAction func InfoButton(sender: UIButton) {
        print("Button hit!")
    }
    @IBAction func Switch(sender: UISwitch) {
        print("Switch!")
        
    }
    @IBOutlet weak var Switch: UISwitch!
    @IBOutlet weak var RowLabel: UILabel!

    public override func setup() {
        height = { BaseRow.estimatedRowHeight }
//        row.title = nil
        print("Text is", row.title)
        RowLabel.text = row.title
        if let value = row.value {
            print("Value is", value)
            Switch.on = value
        }
        super.setup()
        selectionStyle = .None
    }
    
    public override func update() {
        super.update()
        print("At update Text is", row.title)
        RowLabel.text = row.title
        if let value = row.value {
            print("At update, Value is", value)
            Switch.on = value
        }
    }
}

// MARK: SwitchWithInfoButtonRow

public class _SwitchWithInfoButtonRow: Row<Bool, SwitchWithInfoButtonCell> {
    required public init(tag: String?) {
        super.init(tag: tag)
        displayValueFor = nil
        cellProvider = CellProvider<SwitchWithInfoButtonCell>(nibName: "SwitchWithInfoButton")
    }
}


/// Boolean row that has a UISwitch as accessoryType
public final class SwitchWithInfoButtonRow: _SwitchWithInfoButtonRow, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}