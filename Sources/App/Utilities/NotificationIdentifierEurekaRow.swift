import Eureka
import Foundation
import UIKit

public final class NotificationIdentifierRow: Row<NotificationIdentifierTextCell>, RowType {
    public var uppercaseOnly: Bool = true {
        didSet {
            cell.uppercaseOnly = uppercaseOnly
        }
    }

    public required init(tag: String?) {
        super.init(tag: tag)

        cellProvider = CellProvider<NotificationIdentifierTextCell>()

        cell.textField.tag = 999

        if uppercaseOnly {
            cell.textField.autocapitalizationType = .allCharacters

            add(rule: RuleRegExp(regExpr: "[A-Za-z1-9_]+"))
        } else {
            add(rule: RuleRegExp(regExpr: "[A-Z1-9_]+"))
        }

        add(rule: RuleRequired())
    }
}

public class NotificationIdentifierTextCell: TextCell {
    public var uppercaseOnly: Bool = true

    override public func setup() {
        super.setup()

        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .asciiCapable
    }

    override public func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField.tag != 999 { // Only modify rows with the tag 999
            return false
        }

        if string.isEmpty {
            return true
        }

        var regex = "[A-Za-z_ ]+"

        if uppercaseOnly {
            regex = "[A-Z_ ]+"
        }

        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: string)
    }

    override public func textFieldDidChange(_ textField: UITextField) {
        if textField.tag != 999 { // Only modify rows with the tag 999
            return
        }

        textField.text = textField.text?.replacingOccurrences(of: " ", with: "_")
        row.value = textField.text
    }
}
