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
    required public init(tag: String?) {
        super.init(tag: tag)

        cellProvider = CellProvider<NotificationIdentifierTextCell>()

        self.cell.textField.autocapitalizationType = .allCharacters

        self.add(rule: RuleRegExp(regExpr: "[A-Z_]+"))
    }
}

public class NotificationIdentifierTextCell: TextCell {
    public override func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                                   replacementString string: String) -> Bool {

        if string.isEmpty {
            return true
        }
        let regex = "[A-Z_ ]+"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: string)
    }

    public override func textFieldDidChange(_ textField: UITextField) {
        textField.text = textField.text?.replacingOccurrences(of: " ", with: "_")
        row.value = textField.text
    }
}
