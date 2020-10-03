//
//  NotificationIdentifierEurekaRow.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Eureka

public final class NotificationIdentifierRow: Row<NotificationIdentifierTextCell>, RowType {

    public var uppercaseOnly: Bool = true {
        didSet {
            self.cell.uppercaseOnly = self.uppercaseOnly
        }
    }

    required public init(tag: String?) {
        super.init(tag: tag)

        cellProvider = CellProvider<NotificationIdentifierTextCell>()

        self.cell.textField.tag = 999

        if self.uppercaseOnly {
            self.cell.textField.autocapitalizationType = .allCharacters

            self.add(rule: RuleRegExp(regExpr: "[A-Za-z1-9_]+"))
        } else {
            self.add(rule: RuleRegExp(regExpr: "[A-Z1-9_]+"))
        }

        self.add(rule: RuleRequired())
    }
}

public class NotificationIdentifierTextCell: TextCell {
    public var uppercaseOnly: Bool = true

    public override func setup() {
        super.setup()

        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .asciiCapable
    }

    public override func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                                   replacementString string: String) -> Bool {

        if textField.tag != 999 { // Only modify rows with the tag 999
            return false
        }

        if string.isEmpty {
            return true
        }

        var regex = "[A-Za-z_ ]+"

        if self.uppercaseOnly {
            regex = "[A-Z_ ]+"
        }

        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: string)
    }

    public override func textFieldDidChange(_ textField: UITextField) {
        if textField.tag != 999 { // Only modify rows with the tag 999
            return
        }

        textField.text = textField.text?.replacingOccurrences(of: " ", with: "_")
        row.value = textField.text
    }
}
